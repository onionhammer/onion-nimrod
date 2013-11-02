##Reference:
# http://tools.ietf.org/html/rfc6455#section-5
# https://developer.mozilla.org/en-US/docs/WebSockets
# https://developer.mozilla.org/en-US/docs/WebSockets/Writing_WebSocket_server
# https://github.com/warmcat/libwebsockets/tree/master/lib


##TODO:
# Handle pings/pongs
# Handle multiple client sockets
# Implement asyncio support


##Imports
import sockets, strutils, strtabs, parseutils, asyncio, unsigned, sha1
import websocket_utils


##Fields
const magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
const wwwNL       = "\r\L"


##Types
type
  TWebSocketStatusCallback*        = proc(ws: var TWebSocketServer, client: TWebSocket)
  TWebSocketBeforeConnectCallback* = proc(ws: var TWebSocketServer, client: TWebSocket, headers: PStringTable): bool
  TWebSocketMessageCallback*       = proc(ws: var TWebSocketServer, client: TWebSocket, message: string)

  TWebSocket* = object of TObject
    socket*: TSocket

  TWebSocketServer* = object
    server*:         TSocket
    clients*:        seq[TWebSocket]
    buffer:          cstring
    onBeforeConnect: TWebSocketBeforeConnectCallback
    onConnected:     TWebSocketStatusCallback
    onMessage:       TWebSocketMessageCallback
    onDisconnected:  TWebSocketStatusCallback


##Procedures
proc checkUpgrade(client: TSocket, headers: var PStringTable): bool =
  ## Validate request
  if not client.parseHTTPHeader(headers):
    return false

  if headers["upgrade"] != "websocket":
    return false

  var protocol  = headers["Sec-WebSocket-Protocol"]
  var clientKey = headers["Sec-WebSocket-Key"]
  var accept    = sha1.compute(clientKey & magicString).toBase64()

  ## Send accept handshake response
  var response =
    "HTTP/1.1 101 Switching Protocols" & wwwNL &
    "Upgrade: websocket" & wwwNL &
    "Connection: Upgrade" & wwwNL &
    "Sec-WebSocket-Accept: " & accept & wwwNL

  if protocol != "":
    response.add("Sec-WebSocket-Protocol: " & protocol & wwwNL)

  client.send(response & wwwNL)
  return true


proc open*(ws: var TWebSocketServer, port = TPort(8080), address = "127.0.0.1") =
  ## opens a connection
  ws.server  = socket()
  ws.clients = newSeq[TWebSocket]()
  ws.buffer  = cstring(newString(4000))

  if ws.server == InvalidSocket: 
    websocketError("could not open websocket")

  bindAddr(ws.server, port, address)
  listen(ws.server)


proc read(ws: TWebSocketServer, client: TWebSocket, timeout = -1): string =
  var read: int
  var buffer = ws.buffer

  template readRet(size: int, tm = 0): stmt {.immediate.} =
    read = client.socket.recv(buffer, size, tm)
    if read < 2:
      return ""

  template readLength(size: int) =
    ## Read next `size` bytes to determine length
    readRet(size)
    length = 0 #Reset the length to 0

    let max = size * 8
    for i in 1 .. size:
      length += int(buffer[i - 1]) shl (max - (i * 8))

  #Read first two bytes
  readRet(2, timeout)

  var length = int(uint8(buffer[1]) and 127)
  
  #Determine length of message to follow
  if   length == 126: readLength(2)
  elif length == 127: readLength(8)

  #Read the rest of the data being transmitted
  readRet(length + 4)

  result = newString(length)

  #Decode the buffer & copy into result
  var j = 0
  for i in 0 .. length-1:
    result[j] = char(uint8(buffer[i + 4]) xor uint8(buffer[j mod 4]))
    inc(j)


proc send*(ws: TWebSocketServer, client: TWebSocket, message: string) =
  ## Wrap message & send it
  let len    = message.len
  var buffer = ws.buffer

  template put_header(size: int, body: stmt): stmt {.immediate.} =
    buffer[0] = char(129)
    body
    copyMem(addr(buffer[size]), cstring(message), len)
    discard client.socket.send(buffer, size + len)

  if len <= 125:
    put_header(2):
      buffer[1] = char(len)

  elif len <= 65535:
    put_header(4):
      buffer[1] = char(126)
      buffer[2] = char((len shr 8) and 255)
      buffer[3] = char(len and 255)

  else:
    put_header(10):
      buffer[1] = char(127)
      buffer[2] = char((len shr 56) and 255)
      buffer[3] = char((len shr 48) and 255)
      buffer[4] = char((len shr 40) and 255)
      buffer[5] = char((len shr 32) and 255)
      buffer[6] = char((len shr 24) and 255)
      buffer[7] = char((len shr 16) and 255)
      buffer[8] = char((len shr 8) and 255)
      buffer[9] = char(len and 255)


proc close*(ws: var TWebSocketServer) =
  ## closes the connection
  #close all client connections
  for client in ws.clients:
    client.socket.close()

  ws.server.close()
  ws.clients.setLen(0)


proc close*(ws: var TWebSocketServer, client: TWebSocket) =
  ## closes the connection (TODO - proper websocket shutdown)
  client.socket.close()
  ws.clients.remove(client)


proc sendError*(client: TWebSocket, error = "Not Supported") =
  # transmits forbidden message to client and closes socket
  client.socket.send("HTTP/1.1 400 Bad Request" & wwwNL & wwwNL & error)
  client.socket.close()


proc handleServer(ws: var TWebSocketServer) =
  # Accept incoming connection
  var headers = newStringTable(modeCaseInsensitive)
  var client: TWebSocket
  new(client.socket)
  accept(ws.server, client.socket)

  var accepted = checkUpgrade(client.socket, headers)

  if accepted:
    # check with onBeforeConnect
    if ws.onBeforeConnect != nil:
      accepted = ws.onBeforeConnect(ws, client, headers)

    # if connection allowed, add to client list and call onConnected
    if accepted:
      ws.clients.add(client)
      ws.onConnected(ws, client)

  if not accepted:
    # break connection
    client.sendError()


proc handleClient(ws: var TWebSocketServer, client: TWebSocket) =
  ## detect incoming messages
  var message = ws.read(client)

  ## detect disconnect, pass to onDisconnected callback
  ## and remove from client list
  if message == "":
    ws.close(client)
    ws.onDisconnected(ws, client)

  else:
    ws.onMessage(ws, client, message)


proc run*(ws: var TWebSocketServer, port = TPort(8080)) =
  ## Open a synchronous socket listener
  ws.open(port)

  while true:
    # gather up all open sockets
    var rsocks = newSeq[TSocket](ws.clients.len + 1)

    rsocks[0] = ws.server
    for i in 0 .. ws.clients.len-1:
      rsocks[i+1] = ws.clients[i].socket

    # block thread until a socket has changed
    if select_c(rsocks, -1) != 0:

      # if read socket is a client, pass to handleClient
      for client in ws.clients:
        if client.socket in rsocks:
          ws.handleClient(client)

      # if read socket is listener, pass to handleServer
      if ws.server in rsocks:
        ws.handleServer()


##Tests
when isMainModule:

  #Test module
  echo "Running websocket test"

  proc onBeforeConnect(ws: var TWebSocketServer, client: TWebSocket, headers: PStringTable): bool = true

  proc onConnected(ws: var TWebSocketServer, client: TWebSocket) =
    echo "connected"
    ws.send(client, "hello world!")

  proc onMessage(ws: var TWebSocketServer, client: TWebSocket, message: string) =
    echo "message: ", message

  proc onDisconnected(ws: var TWebSocketServer, client: TWebSocket) =
    echo "disconnected: ", ws.clients.len, " clients remaining"


  var ws = TWebSocketServer(
    onBeforeConnect: onBeforeConnect,
    onConnected    : onConnected,
    onMessage      : onMessage,
    onDisconnected : onDisconnected
  )

  ws.run()

  echo "Socket closed"