##Reference:
# http://tools.ietf.org/html/rfc6455#section-5


##TODO:
# Resolve memory issues
# Cleanup
# Finalize external interface


##Imports
import sockets, asyncio, sequtils, strutils, strtabs, parseutils, unsigned, sha1
import websocket_utils


##Fields
const magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
const wwwNL       = "\r\L"


##Types
type
  TWebSocketCallback*              = proc(ws: TWebSocketServer, client: TWebSocket, message: TWebSocketMessage)
  TWebSocketBeforeConnectCallback* = proc(ws: TWebSocketServer, client: TWebSocket, headers: PStringTable): bool

  TWebSocketMessage* = ref object
    fin*, rsv*, opCode*: int
    data*: string
    disconnected: bool

  TWebSocket* = ref object
    case isAsync: bool
    of true:  asyncSocket: PAsyncSocket
    of false: socket: TSocket

  TWebSocketServer* = ref object
    clients:         seq[TWebSocket]
    buffer:          cstring
    onBeforeConnect: TWebSocketBeforeConnectCallback
    onConnected:     TWebSocketCallback
    onMessage:       TWebSocketCallback
    onDisconnected:  TWebSocketCallback
    case isAsync: bool
    of true:
      asyncServer: PAsyncSocket
      dispatcher: PDispatcher
    of false: server: TSocket


##Procedures
proc sendError*(client: TWebSocket, error = "Not Supported") =
  # transmits forbidden message to client and closes socket
  let message = "HTTP/1.1 400 Bad Request" & wwwNL & wwwNL & error

  if client.isAsync:
    client.asyncSocket.send(message)
    client.asyncSocket.close()

  else:
    client.socket.send(message)
    client.socket.close()


proc checkUpgrade(client: TWebSocket, headers: PStringTable): bool =
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

  if client.isAsync:
    client.asyncSocket.send(response & wwwNL)
  else:
    client.socket.send(response & wwwNL)

  return true


proc read(ws: TWebSocketServer, client: TWebSocket, timeout = -1): TWebSocketMessage =
  var read, length: int
  var buffer = ws.buffer
  zeroMem(buffer, buffer.len)

  #If we get to the end of the proc, client is still connected
  result = TWebSocketMessage(data: "")

  template read_next(size: int, tm): stmt =
    #Retrieve next chunk of message
    if client.isAsync:
      read = client.asyncSocket.recv(buffer, size, tm)
    else:
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
  result.opCode = (total and 0xf)

  #Validate frame header
  if result.fin == 0 or result.rsv != 0 or result.opCode == 8:
    # Frame is not FINnished, broken, or client disconnected
    # TODO - handle fin=0 (cant while socket lib is so restrictive)
    result.disconnected = true
    return result

  elif result.opCode in {3 .. 7} or result.opCode >= 0xB:
    # Control or non-control frame, disregard
    echo "control frame..."
    return result

  elif result.opCode in {0x9 .. 0xA}:
    #Ping or Pong, disregard
    return result

  #Determine length of message to follow
  length = int(uint8(buffer[1]) and 127)
  if   length == 126: readLength(2)
  elif length == 127: readLength(8)

  #Read the rest of the data being transmitted
  read_next(length + 4, 0)
  result.data = newString(length)

  #Decode the buffer & copy into result
  var j = 0
  for i in 0 .. length-1:
    result.data[j] = char(byte(buffer[i + 4]) xor byte(buffer[j mod 4]))
    inc(j)


proc send*(ws: TWebSocketServer, client: TWebSocket, message: string) =
  ## Wrap message & send it
  let len    = message.len
  var buffer = ws.buffer

  template put_header(size: int, body: stmt): stmt {.immediate.} =
    buffer[0] = char(129)
    body
    copyMem(addr(buffer[size]), cstring(message), len)
    if client.isAsync:
      discard client.asyncSocket.send(buffer, size + len)
    else:
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
  if ws.isAsync:
    for client in ws.clients:
      client.asyncSocket.close()
    ws.asyncServer.close()

  else:
    for client in ws.clients:
      client.socket.close()
    ws.server.close()

  ws.server  = nil
  ws.clients = nil
  ws.buffer  = nil


proc close*(ws: var TWebSocketServer, client: TWebSocket) =
  ## closes the connection
  # remove the item from the list of clients
  ws.clients = ws.clients.filter(
    proc(c: TWebSocket): bool = c != client
  )

  if ws.isAsync:
    client.asyncSocket.close()

  else:
    client.socket.close()


proc handleClient(ws: var TWebSocketServer, client: TWebSocket) =
  ## detect disconnect, pass to onDisconnected callback
  ## and remove from client list
  var message = ws.read(client)

  if message.disconnected:
    ws.close(client)

    if ws.onDisconnected != nil:
      ws.onDisconnected(ws, client, message)

  elif message.opCode == 1: #For now we just handle text frames
    if ws.onMessage == nil: websocketError("onMessage event not bound")
    ws.onMessage(ws, client, message)


proc handleConnect(ws: var TWebSocketServer, client: TWebSocket, headers: PStringTable): bool =
  # check if upgrade is requested (also sends response)
  if not checkUpgrade(client, headers):
    return false

  # check with onBeforeConnect
  if ws.onBeforeConnect != nil and not ws.onBeforeConnect(ws, client, headers):
    return false

  # if connection allowed, add to client list and call onConnected
  if ws.onConnected == nil: websocketError("onConnected event not bound")
  ws.clients.add(client)
  ws.onConnected(ws, client, nil)
  return true


proc handleAsyncUpgrade(ws: var TWebSocketServer, socket: PAsyncSocket): TWebSocket =
  var headers = newStringTable(modeCaseInsensitive)
  result      = TWebSocket(isAsync: true, asyncSocket: socket)
  
  # parse HTTP headers & handle connection
  if not result.asyncSocket.parseHTTPHeader(headers) or
     not ws.handleConnect(result, headers):
    result.sendError()
    result = nil


proc handleAccept(ws: var TWebSocketServer, server: PAsyncSocket) =
  # accept incoming connection
  var client: TWebSocket
  var socket: PAsyncSocket
  new(socket)
  accept(server, socket)

  var owner = ws
  socket.handleRead = proc(socket: PAsyncSocket) =
    if client != nil: owner.handleClient(client)
    else: client = owner.handleAsyncUpgrade(socket)

  ws.dispatcher.register(socket)


proc open*(address = "127.0.0.1", port = TPort(8080), isAsync = true): TWebSocketServer =
  ## open a websocket server
  var ws: TWebSocketServer
  new(ws)

  ws.isAsync = isAsync
  ws.clients = newSeq[TWebSocket]()
  ws.buffer  = cstring(newString(4000))

  if isAsync:
    ws.asyncServer = asyncSocket()
    bindAddr(ws.asyncServer, port, address)
    listen(ws.asyncServer)

    ws.asyncServer.handleAccept =
      proc(s: PAsyncSocket) = ws.handleAccept(s)

  else:
    ws.server = socket()
    if ws.server == InvalidSocket: 
      websocketError("could not open websocket")

    bindAddr(ws.server, port, address)
    listen(ws.server)

  return ws


proc run*(ws: var TWebSocketServer) =
  ## Begins listening for incoming websocket requests
  if ws.isAsync: websocketError("run() only works with non-async websocket servers")

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
        var client  = TWebSocket(isAsync: false)
        new(client.socket)
        accept(ws.server, client.socket)

        # parse HTTP headers & handle connection
        if not client.socket.parseHTTPHeader(headers) or
           not ws.handleConnect(client, headers):
          client.sendError()


proc register*(dispatcher: PDispatcher, ws: var TWebSocketServer) =
  ## Register the websocket with an asyncio dispatcher object
  if not ws.isAsync:
    websocketError("register() only works with async websocket servers")

  dispatcher.register(ws.asyncServer)
  ws.dispatcher = dispatcher


##Tests
when isMainModule:

  #proc onBeforeConnect(ws: var TWebSocketServer, client: TWebSocket, headers: PStringTable): bool = true

  proc onConnected(ws: TWebSocketServer, client: TWebSocket, message: TWebSocketMessage) =
    ws.send(client, "hello world!")

  proc onMessage(ws: TWebSocketServer, client: TWebSocket, message: TWebSocketMessage) =
    echo "message: ", message.data

  proc onDisconnected(ws: TWebSocketServer, client: TWebSocket, message: TWebSocketMessage) =
    echo "client left, remaining: ", ws.clients.len

  echo "Running websocket test"

  #Choose which type of websocket to test
  const testAsync = true

  var ws            = open(isAsync = testAsync)
  ws.onConnected    = onConnected
  ws.onMessage      = onMessage
  ws.onDisconnected = onDisconnected

  when not testAsync:
    ws.run()

  else:
    let dispatch = newDispatcher()
    dispatch.register(ws)

    while dispatch.poll(): nil
