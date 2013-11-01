##Reference:
# http://tools.ietf.org/html/rfc6455#section-5
# https://developer.mozilla.org/en-US/docs/WebSockets
# https://developer.mozilla.org/en-US/docs/WebSockets/Writing_WebSocket_server
# https://github.com/warmcat/libwebsockets/tree/master/lib


##Imports
import sockets, strutils, strtabs, parseutils, asyncio, hashes, sha1, unsigned


##Fields
const magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
const wwwNL       = "\r\L"


##Types
type
  TWebSocketConnectedCallback* = proc(server: TWebSocketServer, client: TWebSocket)

  TWebSocket* = object of TObject
    socket*: TSocket

  TWebSocketServer* = object# of TWebSocket
    headers: PStringTable
    rsocks: seq[TSocket]
    server: TSocket
    buffer: cstring

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


proc handshake(client: TSocket, headers: PStringTable) =
  ## validate request
  var protocol  = headers["Sec-WebSocket-Protocol"]
  var clientKey = headers["Sec-WebSocket-Key"]

  ## build accept string
  var accept = sha1.compute(clientKey & magicString).toBase64()

  ## build response
  sendResponse(client, protocol, accept)


proc parseUpgrade(client: TSocket, headers: var PStringTable) : bool =
  ## parse websocket connection header
  var header = ""
  client.readLine(header)
  
  if header == "":
    client.close()
    return false

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

  handshake(client, headers)

  return true


proc websocketError*(msg: string) {.noreturn.} =
  ## raises an EWebSocket exception with message `msg`.
  var e: ref EWebSocket
  new(e)
  e.msg = msg
  raise e


proc read(ws: TWebSocketServer, client: TWebSocket): string =
  var buffer = ws.buffer
  var read   = client.socket.recv(buffer, 2)
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
  let len = message.len
  var buffer = ws.buffer

  template put_header(size: int, body: stmt): stmt {.immediate.} =
    buffer[0] = char(129)
    body
    copyMem(addr(buffer[size]), cstring(message), len)
    discard client.socket.send(buffer, size + len)

  if len <= 125:
    put_header 2:
      buffer[1] = char(len)

  elif len <= 65535:
    put_header 4:
      buffer[1] = char(126)
      buffer[2] = char((len shr 8) and 255)
      buffer[3] = char(len and 255)

  else:
    put_header 10:
      buffer[1] = char(127)
      buffer[2] = char((len shr 56) and 255)
      buffer[3] = char((len shr 48) and 255)
      buffer[4] = char((len shr 40) and 255)
      buffer[5] = char((len shr 32) and 255)
      buffer[6] = char((len shr 24) and 255)
      buffer[7] = char((len shr 16) and 255)
      buffer[8] = char((len shr 8) and 255)
      buffer[9] = char(len and 255)


proc open*(ws: var TWebSocketServer, port = TPort(8080), address = "127.0.0.1") =
  ## opens a connection
  ws.buffer = cstring(newString(4000))
  ws.server = socket()

  if ws.server == InvalidSocket: 
    websocketError("could not open websocket")

  bindAddr(ws.server, port, address)
  listen(ws.server)


proc close*(ws: var TWebSocketServer) =
  ## closes the connection
  ws.server.close()


proc next*(ws: var TWebSocketServer, 
           onConnected: TWebSocketConnectedCallback, 
           timeout = -1): bool =
  ## proceed to the first/next request. Waits ``timeout`` miliseconds for a
  ## request, if ``timeout`` is `-1` then this function will never time out.

  ws.rsocks.add(ws.server)

  if select(ws.rsocks, timeout) == 1 and ws.rsocks.len == 0:
    block: #TODO - if rsock has server (select not impl correctly)
      var ip: string
      var client: TWebSocket
      new(client.socket)
      acceptAddr(ws.server, client.socket, ip)
      
      #Accept websocket upgrade
      if parseUpgrade(client.socket, ws.headers):
        onConnected(ws, client)

      return false


proc run*(onConnected: TWebSocketConnectedCallback, port = TPort(8080)) =
  ## runs a synchronous websocket listener
  var stop = false
  var ws: TWebSocketServer
  ws.rsocks = newSeq[TSocket]()
  ws.headers = newStringTable(modeCaseInsensitive)
  ws.open(port)

  while not stop:
    stop = ws.next(onConnected)


##Tests
when isMainModule:

  #Test module
  echo "Running websocket test"
  
  var wsocks = newSeq[TSocket]()

  proc onConnected(ws: TWebSocketServer, client: TWebSocket) =
    ws.send(client, "Hello world 1")
    ws.send(client, "Hello world 2")
    ws.send(client, "Hello world 3")

    wsocks.add(client.socket)
    if select(wsocks, -1) == 1: 
      echo ws.read(client)
      echo ws.read(client)
      echo ws.read(client)

    client.socket.close()

  run(onConnected)

  echo "Socket closed"
  