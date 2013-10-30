import sockets, strutils, strtabs, parseutils, asyncio, hashes, sha1

##Fields
const magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
const wwwNL       = "\r\L"

##Types
type
  TWebSocket* = object of TObject
    server: TSocket
    bufLen: int
    client*: TSocket
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

proc handshake(client: TSocket, header: PStringTable) : bool =
  ## validate request
  var protocol  = header["Sec-WebSocket-Protocol"]
  var clientKey = header["Sec-WebSocket-Key"]

  ## build accept string
  var accept = $sha1.compute(clientKey & magicString)

  ## build response
  sendResponse(client, protocol, accept)
  
  return true

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
  if L > 0 and recv(ws.client, cstring(ws.input), L) != L:
    websocketError("could ont read all data")
  setLen(ws.input, L)

proc open*(ws: var TWebSocket, port = TPort(8080), address = "127.0.0.1") =
  ## opens a connection
  ws.bufLen = 4000
  ws.input  = newString(ws.bufLen)
  ws.server = socket()

  new(ws.client) #Initialize a socket for `next`

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
    new(ws.client)
    accept(ws.server, ws.client)
    
    var headers = newStringTable(modeCaseInsensitive)
    
    #TODO - websocket handshake
    if not parseHeader(ws.client, headers):
      return false

    if not handshake(ws.client, headers):
      return false

    return true

proc run*(handleRequest: proc(client: TSocket, input: string): bool {.nimcall.}, 
          port = TPort(8080)) =
  
  var stop = false
  var ws: TWebSocket
  ws.open(port)

  while not stop:
    if ws.next():
      stop = handleRequest(ws.client, ws.input)
      ws.client.close()

  ws.close()


##Tests
when isMainModule:

  #Test module
  echo "Running websocket test"
  
  run(proc (client: TSocket, input: string): bool = 
    echo "client connected"
  )

  echo "Socket closed"
  