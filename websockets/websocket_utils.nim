##Imports
import sockets, strtabs, parseutils, sha1


##Types
type EWebSocket* = object of EIO


##Fields
const magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
const wwwNL       = "\r\L"


## Websocket utility procedures
proc websocketError*(msg: string) {.noreturn.} =
  ## raises an EWebSocket exception with message `msg`.
  var e: ref EWebSocket
  new(e)
  e.msg = msg
  raise e

proc parseHTTPHeader*(client: TSocket, headers: var PStringTable): bool =
  ## parse HTTP header
  var header = ""
  client.readLine(header)
  
  if header == "":
    client.close()
    return false

  let newLine = {'\c', '\L'}

  while true:
    client.readLine(header)

    if header == "\c\L":
      return true

    elif header != "":
      var key, value: string

      var i = header.parseUntil(key, ':') + 1
      i    += header.skipWhiteSpace(i)
      i    += header.parseUntil(value, newLine, i)

      headers[key] = value

    else:
      client.close()
      return false


proc checkUpgrade*(client: TSocket, headers: var PStringTable): bool =
  ## Validate request
  if not client.parseHTTPHeader(headers) or headers["upgrade"] != "websocket":
    return false

  try:
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

    response.add(wwwNL)
    client.send(response)
    return true

  except:
    echo "Exception occurred.. was blocked :|"
    return false


##These two procs should not be needed once sockets.nim is fixed
proc pruneSocketSet*(s: var seq[TSocket], fd: seq[TSocket]) =
  var i = 0
  var L = s.len
  while i < L:
    if s[i] in fd:
      s[i] = s[L-1]
      dec(L)
    else:
      inc(i)
  setLen(s, L)
  

proc select_c*(rsocks: var seq[TSocket], timeout = -1): int =
  #TODO - Remove this when lib/pure select is fixed
  proc cpySeq(input: seq[TSocket]) : seq[TSocket] =
    result = newSeq[TSocket](input.len)
    for i in 0..input.len-1:
      result[i] = input[i]

  var rd = cpySeq(rsocks)

  result = sockets.select(rd, timeout)
  pruneSocketSet(rsocks, rd)


proc remove*[T](items: var seq[T], item: T) =
  var len = items.len - 1
  for i in 0 .. len:
    if items[i] == item:
      if i < len:
        items[i] = items[i+1]
      items.setLen(len)
      break