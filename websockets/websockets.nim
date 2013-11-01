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
  TWebSocketConnectedCallback* = proc(server: TWebSocketServer, client: TWebSocket)

  TWebSocket* = object of TObject
    socket*: TSocket

  TWebSocketServer* = object
    server: TSocket
    buffer: cstring


##Procedures
proc checkUpgrade(client: TSocket, headers: var PStringTable): bool =
  ## Validate request
  if not client.parseHTTPHeader(headers):
    return false

  if headers["upgrade"] != "websocket":
    client.send("Not Supported")
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
  ws.buffer = cstring(newString(4000))
  ws.server = socket()

  if ws.server == InvalidSocket: 
    websocketError("could not open websocket")

  bindAddr(ws.server, port, address)
  listen(ws.server)


proc read*(ws: TWebSocketServer, client: TWebSocket, timeout = -1): string =
  var buffer = ws.buffer
  var read   = client.socket.recv(buffer, 2, timeout)
  var length = int(uint8(buffer[1]) and 127)
  
  template readLength(size: int) =
    ## Read next `size` bytes to determine length
    read   = client.socket.recv(buffer, size, 0)
    length = 0 #Reset the length to 0

    let max = size * 8
    for i in 1 .. size:
      length += int(buffer[i - 1]) shl (max - (i * 8))

  if   length == 126: readLength(2)
  elif length == 127: readLength(8)

  #Read the rest of the data being transmitted
  read   = client.socket.recv(buffer, length + 4, 0)
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


proc close*(ws: TWebSocketServer) =
  ## closes the connection
  #TODO - close all client connections
  ws.server.close()


proc close*(client: TWebSocket) =
  ## closes the connection (TODO - proper websocket shutdown)
  client.socket.close()


proc next*(ws: var TWebSocketServer, 
           onConnected: TWebSocketConnectedCallback, 
           timeout = -1): bool =
  ## proceed to the first/next request. Waits ``timeout`` miliseconds for a
  ## request, if ``timeout`` is `-1` then this function will never time out.

  var rsocks = @[ws.server]

  if select(rsocks, timeout) == 1:
    block: #TODO - if rsock has server (select not impl correctly)
      var headers = newStringTable(modeCaseInsensitive)
      var client: TWebSocket
      new(client.socket)
      accept(ws.server, client.socket)
      
      #Check if incoming client wants websocket
      if checkUpgrade(client.socket, headers):
        #TODO - client connection has been upgraded
        onConnected(ws, client)
      else:
        #Client is not trying to connect via websocket
        client.close()

      return true


proc run*(onConnected: TWebSocketConnectedCallback, port = TPort(8080)) =
  ## runs a synchronous websocket listener
  var ws: TWebSocketServer

  ws.open(port)

  while ws.next(onConnected): nil


##Tests
when isMainModule:

  #Test module
  echo "Running websocket test"
  
  var wsocks = newSeq[TSocket]()

  proc onConnected(ws: TWebSocketServer, client: TWebSocket) =
    ws.send(client, "Hello world!")

    wsocks.add(client.socket)
    if select(wsocks, -1) == 1:
      echo ws.read(client)

    client.close()

  run(onConnected)

  echo "Socket closed"