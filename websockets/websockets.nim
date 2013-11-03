##Reference:
# http://tools.ietf.org/html/rfc6455#section-5


##TODO:
# Implement asyncio support


##Imports
import sockets, strutils, strtabs, parseutils, asyncio, unsigned, sha1
import websocket_utils


##Fields
const magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
const wwwNL       = "\r\L"


##Types
type
  TWebSocketCallback*              = proc(ws: var TWebSocketServer, client: TWebSocket, message: PWebSocketMessage)
  TWebSocketBeforeConnectCallback* = proc(ws: var TWebSocketServer, client: TWebSocket, headers: PStringTable): bool

  PWebSocketMessage* = ref TWebSocketMessage
  TWebSocketMessage* = object
    fin*, rsv*, opCode*: int
    data*: string
    code*: int
    disconnected: bool

  TWebSocket* = object of TObject
    socket*: TSocket

  TWebSocketServer* = object
    server*:         TSocket
    clients*:        seq[TWebSocket]
    buffer:          cstring
    onBeforeConnect: TWebSocketBeforeConnectCallback
    onConnected:     TWebSocketCallback
    onMessage:       TWebSocketCallback
    onDisconnected:  TWebSocketCallback


##Procedures
proc sendError*(client: TWebSocket, error = "Not Supported") =
  # transmits forbidden message to client and closes socket
  client.socket.send("HTTP/1.1 400 Bad Request" & wwwNL & wwwNL & error)
  client.socket.close()


proc checkUpgrade(client: TSocket, headers: PStringTable): bool =
  ## Validate request
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


proc read(ws: TWebSocketServer, client: TWebSocket, timeout = -1): PWebSocketMessage =
  var read, length: int
  var buffer = ws.buffer

  #If we get to the end of the proc, client is still connected
  result = PWebSocketMessage(data: "")

  template read_next(size: int, tm): stmt =
    #Retrieve next chunk of message
    read = client.socket.recv(buffer, size, tm)

    #If bytes read == 0 client disconnected
    if read == 0: 
      result.disconnected = true
      return result

  template readLength(size: int) =
    ## Read next `size` bytes to determine length
    read_next(size, 0)
    length = 0 #Reset the length to 0

    let max = size * 8
    for i in 1 .. size:
      length += int(buffer[i - 1]) shl (max - (i * 8))

  #Read first two bytes
  read_next(2, timeout)

  #Rretrieve the fin/rsv/opcode
  var total     = int(buffer[0])
  result.fin    = (total and 128) shr 7
  result.rsv    = (total and 127) shr 4
  result.opCode = total and 0xf

  #Check opCode
  if result.rsv != 0 or result.opCode == 8:
    result.disconnected = true

  #Determine length of message to follow
  length = int(uint8(buffer[1]) and 127)
  if   length == 126: readLength(2)
  elif length == 127: readLength(8)

  #If there is a disconnect code to be read, offset message by 2 bytes
  var codeOffset = 0
  if result.disconnected:
    codeOffset = -2

  #Read the rest of the data being transmitted
  read_next(length + 4, 0)
  result.data = newString(length + codeOffset)

  #Decode the buffer & copy into result
  var j = 0
  for i in 0 .. length-1:
    if result.disconnected and i < 2:
      #Parse out close code
      var code = int(buffer[i + 4]) xor int(buffer[j mod 4])
      result.code = (result.code shl 8) + code

    else:
      result.data[j + codeOffset] = char(byte(buffer[i + 4]) xor byte(buffer[j mod 4]))

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
  ws.server  = nil
  ws.clients = nil
  ws.buffer  = nil


proc close*(ws: var TWebSocketServer, client: TWebSocket) =
  ## closes the connection
  client.socket.close()
  ws.clients.remove(client)


proc handleConnect(ws: var TWebSocketServer, client: TWebSocket, headers: PStringTable): bool =
  # check if upgrade is requested (also sends response)
  if not checkUpgrade(client.socket, headers):
    return false

  # check with onBeforeConnect
  if ws.onBeforeConnect != nil and not ws.onBeforeConnect(ws, client, headers):
    return false

  # if connection allowed, add to client list and call onConnected
  ws.clients.add(client)
  ws.onConnected(ws, client, nil)
  return true


proc handleClient(ws: var TWebSocketServer, client: TWebSocket) =
  ## detect disconnect, pass to onDisconnected callback
  ## and remove from client list
  var message = ws.read(client)

  if message.disconnected:
    ws.close(client)
    ws.onDisconnected(ws, client, message)

  elif message.opCode == 1: #For now we just handle text frames
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

      # if read socket is listener, pass to handleConnect
      if ws.server in rsocks:

        # Accept incoming connection
        var headers = newStringTable(modeCaseInsensitive)
        var client: TWebSocket
        new(client.socket)
        accept(ws.server, client.socket)

        # parse HTTP headers & handle connection
        if not client.socket.parseHTTPHeader(headers) or
           not ws.handleConnect(client, headers):
          client.sendError()
        

##Tests
when isMainModule:

  #Test module
  echo "Running websocket test"

  #proc onBeforeConnect(ws: var TWebSocketServer, client: TWebSocket, headers: PStringTable): bool = true

  proc onConnected(ws: var TWebSocketServer, client: TWebSocket, message: PWebSocketMessage) =
    echo "connected"
    ws.send(client, "hello world!")

  proc onMessage(ws: var TWebSocketServer, client: TWebSocket, message: PWebSocketMessage) =
    echo "message: ", message.data

  proc onDisconnected(ws: var TWebSocketServer, client: TWebSocket, message: PWebSocketMessage) =
    echo "disconnected with code: ", message.code
    echo "disconnect message: ", message.data

  var ws = TWebSocketServer(
    onConnected    : onConnected,
    onMessage      : onMessage,
    onDisconnected : onDisconnected
  )

  ws.run()

  echo "Socket closed"