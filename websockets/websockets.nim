##Reference:
# https://developer.mozilla.org/en-US/docs/WebSockets
# https://developer.mozilla.org/en-US/docs/WebSockets/Writing_WebSocket_server
# https://github.com/warmcat/libwebsockets/tree/master/lib

import sockets, strutils, strtabs, parseutils, asyncio, hashes, sha1

##Fields
const magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
const wwwNL       = "\r\L"

##Types
type
  TWebSocketConnectedCallback* = proc(client: TWebSocket): bool
  TWebSocket* = object of TObject
    server: TSocket
    bufLen: int
    socket*: TSocket
    input*: string  ## the input buffer

type EWebSocket* = object of EIO

##Procedures
proc sendResponse(client: TSocket, protocol, accept: string) =
  ## Send accept handshake response
  client.send("HTTP/1.1 101 Switching Protocols" & wwwNL)
  client.send("Upgrade: websocket" & wwwNL)
  client.send("Connection: Upgrade" & wwwNL)
  client.send("Sec-WebSocket-Accept: " & accept & wwwNL)
  if protocol != "":
    client.send("Sec-WebSocket-Protocol: " & protocol & wwwNL)
  client.send(wwwNL)

proc handshake(client: TSocket, header: PStringTable) =
  ## validate request
  var protocol  = header["Sec-WebSocket-Protocol"]
  var clientKey = header["Sec-WebSocket-Key"]

  ## build accept string
  var accept = sha1.compute(clientKey & magicString).toBase64()

  ## build response
  sendResponse(client, protocol, accept)

proc parseHeader(client: TSocket, headers: var PStringTable) : bool =
  ## parse websocket connection header
  var data = ""
  client.readLine(data)
  if data == "":
    client.close()
    return false

  headers["path"] = data

  var header = ""
  while true:
    client.readLine(header)

    if header == "\c\L":
      break

    if header != "":
      var key   = ""
      var value = ""

      var i = header.parseUntil(key, ':')
      inc(i) # skip :
      i += header.skipWhiteSpace(i)
      i += header.parseUntil(value, {'\c', '\L'}, i)
      headers[key] = value

    else:
      client.close()
      return false

  return true

proc websocketError*(msg: string) {.noreturn.} =
  ## raises an EWebSocket exception with message `msg`.
  var e: ref EWebSocket
  new(e)
  e.msg = msg
  raise e

proc recvBuffer(ws: var TWebSocket, L: int) =
  if L > ws.bufLen:
    ws.bufLen = L
    ws.input  = newString(L)
  if L > 0 and recv(ws.socket, cstring(ws.input), L) != L:
    websocketError("could not read all data")
  setLen(ws.input, L)

proc send*(ws: TWebSocket, message: string) =
  # Wrap message (TODO - break out)
  var header = newString(10)
  var startInd: int

  header[0] = char(129)
  let len = message.len
  if len <= 125:
    header[1] = char(len)
    startInd = 2

  elif len <= 65535:
    header[1] = char(126)
    header[2] = char((len shr 8) and 255)
    header[3] = char(len and 255)
    startInd = 4

  else:
    header[1] = char(127)
    header[2] = char((len shr 56) and 255)
    header[3] = char((len shr 48) and 255)
    header[4] = char((len shr 40) and 255)
    header[5] = char((len shr 32) and 255)
    header[6] = char((len shr 24) and 255)
    header[7] = char((len shr 16) and 255)
    header[8] = char((len shr 8) and 255)
    header[9] = char(len and 255)
    startInd = 10

  var buffer = cstring(header.substr(0, startInd-1) & message)
  discard ws.socket.send(buffer, buffer.len)

proc open*(ws: var TWebSocket, port = TPort(8080), address = "127.0.0.1") =
  ## opens a connection
  ws.bufLen = 4000
  ws.input  = newString(ws.bufLen)
  ws.server = socket()

  if ws.server == InvalidSocket: websocketError("could not open websocket")

  bindAddr(ws.server, port, address)
  listen(ws.server)

proc close*(ws: var TWebSocket) =
  ## closes the connection
  ws.server.close()

proc next*(ws: var TWebSocket, timeout = -1): bool =
  ## proceed to the first/next request. Waits ``timeout`` miliseconds for a
  ## request, if ``timeout`` is `-1` then this function will never time out.
  ## Returns `True` if a new request has been processed.
  var rsocks = @[ws.server]

  if select(rsocks, timeout) == 1 and rsocks.len == 0:
    block: #TODO - if rsock has server
      new(ws.socket)
      accept(ws.server, ws.socket)
      
      var headers = newStringTable(modeCaseInsensitive)
      
      #TODO - websocket handshake
      if not parseHeader(ws.socket, headers):
        return false

      handshake(ws.socket, headers)
      return true

proc run*(onConnected: TWebSocketConnectedCallback, port = TPort(8080)) =
  ## runs a synchronous websocket listener
  var stop = false
  var ws: TWebSocket
  ws.open(port)

  while not stop:
    if ws.next():
      stop = onConnected(ws)


##Tests
when isMainModule:

  #Test module
  echo "Running websocket test"

  proc onConnected(client: TWebSocket): bool =
    client.send("Hello world!" & wwwNL)
    echo "client connected"
    #client.socket.close()
  
  run(onConnected)

  echo "Socket closed"
  