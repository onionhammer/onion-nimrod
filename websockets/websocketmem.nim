##Reference:
# http://tools.ietf.org/html/rfc6455#section-5


##TODO:
# Resolve memory issues
# Cleanup
# Finalize external interface


## Imports
import sockets, asyncio, strutils, strtabs, parseutils, unsigned, sha1, terminal
import websocket_utils

export strtabs


## Fields
const magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
const wwwNL       = "\r\L"

## Types
type
  WebSocketCallback*              = proc(ws: WebSocketServer, client: WebSocket, message: WebSocketMessage)
  WebSocketBeforeConnectCallback* = proc(ws: WebSocketServer, client: WebSocket, headers: StringTableRef): bool

  WebSocketMessage* = ref object
    fin*, rsv*, opCode*: int
    data*: string
    disconnected: bool

  WebSocket* = ref object
    asyncSocket: AsyncSocket

  WebSocketServer* = ref object
    clients*:         seq[WebSocket]
    buffer:           cstring
    strBuf:           string
    onBeforeConnect*: WebSocketBeforeConnectCallback
    onConnected*:     WebSocketCallback
    onMessage*:       WebSocketCallback
    onDisconnected*:  WebSocketCallback
    asyncServer: AsyncSocket
    dispatcher: Dispatcher


## Procedures
proc sendError*(client: WebSocket, error = "Not Supported") =
  # transmits forbidden message to client and closes socket
  let message = "HTTP/1.1 400 Bad Request" & wwwNL & wwwNL & error
  client.asyncSocket.send(message)
  client.asyncSocket.close()


proc checkUpgrade(client: WebSocket, headers: StringTableRef): bool =
  ## Validate request
  if headers["upgrade"] != "websocket":
    return false

  var protocol  = headers["Sec-WebSocket-Protocol"]
  var clientKey = headers["Sec-WebSocket-Key"]
  var accept    = sha1.compute(clientKey & magicString).toBase64()

  # Send accept handshake response
  var response =
    "HTTP/1.1 101 Switching Protocols" & wwwNL &
    "Upgrade: websocket" & wwwNL &
    "Connection: Upgrade" & wwwNL &
    "Sec-WebSocket-Accept: " & accept & wwwNL

  if protocol != "":
    response.add("Sec-WebSocket-Protocol: " & protocol & wwwNL)

  client.asyncSocket.send(response & wwwNL)

  return true


proc read(ws: WebSocketServer, client: WebSocket, timeout = -1): WebSocketMessage =
  var read, length: int
  var buffer = ws.buffer

  # If we get to the end of the proc, client is still connected
  new(result)

  template read_next(size: int, tm): stmt =
    #Retrieve next chunk of message
    read = client.asyncSocket.recv(buffer, size, tm)

    #If bytes read == 0 client disconnected
    if read == 0:
      result.disconnected = true
      return result

  template readLength(size: int) =
    ## Read next `size` bytes to determine length
    read_next(size, 0)
    length = 0 # Reset the length to 0

    let max = size * 8
    for i in 1 .. size:
      length += int(buffer[i - 1]) shl (max - (i * 8))

  # Read first two bytes
  read_next(2, timeout)

  # Retrieve the fin/rsv/opcode
  let total     = int(buffer[0])
  result.fin    = (total and 128) shr 7
  result.rsv    = (total and 127) shr 4
  result.opCode = (total and 0xf)

  # Validate frame header
  if result.fin == 0 or result.rsv != 0 or result.opCode == 8:
    # Frame is not FINnished, broken, or client disconnected
    # TODO - handle fin=0 (cant while socket lib is so restrictive)
    result.disconnected = true
    result.data = ""
    return result

  elif result.opCode in {3 .. 7} or result.opCode >= 0xB:
    # Control or non-control frame, disregard
    result.data = ""
    return result

  elif result.opCode in {0x9 .. 0xA}:
    # Ping or Pong, disregard
    result.data = ""
    return result

  # Determine length of message to follow
  length = int(uint8(buffer[1]) and 127)
  if   length == 126: readLength(2)
  elif length == 127: readLength(8)

  # Read the rest of the data being transmitted
  read_next(length + 4, 0)
  result.data = newString(length)

  # Decode the buffer & copy into result
  var j = 0
  for i in 0 .. < length:
    result.data[j] = char(byte(buffer[i + 4]) xor byte(buffer[j mod 4]))
    inc j


proc send*(ws: WebSocketServer, client: WebSocket, message: string) =
  ## Wrap message & send it
  let mLen   = message.len
  var buffer = ws.buffer

  template put_header(size: int, body: stmt): stmt {.immediate.} =
    buffer[0] = char(129)
    body
    copyMem(addr(buffer[size]), cstring(message), mLen)
    discard client.asyncSocket.send(buffer, size + mLen)

  if mLen <= 125:
    put_header(2):
      buffer[1] = char(mLen)

  elif mLen <= 65535:
    put_header(4):
      buffer[1] = char(126)
      buffer[2] = char((mLen shr 8) and 255)
      buffer[3] = char(mLen and 255)

  else:
    put_header(10):
      buffer[1] = char(127)
      buffer[2] = char((mLen shr 56) and 255)
      buffer[3] = char((mLen shr 48) and 255)
      buffer[4] = char((mLen shr 40) and 255)
      buffer[5] = char((mLen shr 32) and 255)
      buffer[6] = char((mLen shr 24) and 255)
      buffer[7] = char((mLen shr 16) and 255)
      buffer[8] = char((mLen shr 8) and 255)
      buffer[9] = char(mLen and 255)


proc close*(ws: var WebSocketServer) =
  ## closes the connection
  # close all client connections
  for client in ws.clients:
    client.asyncSocket.close()
  ws.asyncServer.close()
  ws.asyncServer = nil

  ws.clients = nil
  ws.strBuf  = nil
  ws.buffer  = nil


proc close*(ws: var WebSocketServer, client: WebSocket) =
  ## closes the connection
  # remove the item from the list of clients
  var i = 0
  while i < ws.clients.len:
    var c = ws.clients[i]
    if c == client:
      ws.clients.del(i); break
    inc(i)

  client.asyncSocket.close()


proc handleClient(ws: var WebSocketServer, client: WebSocket) =
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


proc handleConnect(ws: var WebSocketServer, client: WebSocket, headers: StringTableRef): bool =
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


proc handleAsyncUpgrade(ws: var WebSocketServer, socket: AsyncSocket): WebSocket =
  var headers = newStringTable(modeCaseInsensitive)
  new(result)
  result.asyncSocket = socket

  # parse HTTP headers & handle connection
  if not result.asyncSocket.parseHTTPHeader(headers) or
     not ws.handleConnect(result, headers):
    result.sendError()
    result = nil


proc handleAccept(ws: var WebSocketServer, server: AsyncSocket) =
  # accept incoming connection
  var socket: AsyncSocket
  new(socket)
  accept(server, socket)

  var client: WebSocket
  var owner = ws
  socket.handleRead = proc(socket: AsyncSocket) {.closure, gcsafe.} =
    if client != nil: owner.handleClient(client)
    else:             client = owner.handleAsyncUpgrade(socket)

  ws.dispatcher.register(socket)


proc open*(address = "", port = Port(8080)): WebSocketServer =
  ## open a websocket server
  var ws: WebSocketServer
  new(ws)

  ws.clients = newSeq[WebSocket](2)
  ws.strBuf  = newString(4096)
  ws.buffer  = cstring(ws.strBuf)

  ws.asyncServer = asyncSocket()
  ws.asyncServer.setSockOpt(OptReuseAddr, true)
  bindAddr(ws.asyncServer, port, address)
  listen(ws.asyncServer)

  ws.asyncServer.handleAccept =
    proc(s: AsyncSocket) = ws.handleAccept(s)

  return ws


proc register*(dispatcher: Dispatcher, ws: var WebSocketServer) =
  ## Register the websocket with an asyncio dispatcher object
  dispatcher.register(ws.asyncServer)
  ws.dispatcher = dispatcher


## Tests
when isMainModule:

  proc onConnected(ws: WebSocketServer, client: WebSocket, message: WebSocketMessage) =
    ws.send(client, "hello world!")

  proc onMessage(ws: WebSocketServer, client: WebSocket, message: WebSocketMessage) =
    discard

  proc onDisconnected(ws: WebSocketServer, client: WebSocket, message: WebSocketMessage) =
    discard

  #Choose which type of websocket to test
  var ws            = open()
  ws.onConnected    = onConnected
  ws.onMessage      = onMessage
  ws.onDisconnected = onDisconnected

  let dispatch = newDispatcher()
  dispatch.register(ws)

  const spin = [ '\\', '|', '/', '-' ]
  var i = 0
  while dispatch.poll():
    eraseScreen()
    setCursorPos 0,0

    stdout.write getOccupiedMem().formatSize()
    echo " ", spin[i mod 4]
    echo "clients: ", ws.clients.len
    inc i