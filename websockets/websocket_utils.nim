##Imports
import sockets, asyncio, strtabs, parseutils, sha1


##Types
type EWebSocket* = object of IOError


## Websocket utility procedures
proc websocketError*(msg: string) {.noreturn.} =
  ## raises an EWebSocket exception with message `msg`.
  var e: ref EWebSocket
  new(e)
  e.msg = msg
  raise e


template parseHTTPHeader(header: expr, readline: stmt): stmt {.immediate.} =
  var header = ""
  readline

  if header == "":
    return false

  let newLine = {'\c', '\L'}

  while true:
    readline

    if header == "\c\L":
      return true

    elif header != "":
      var key, value: string
      var i = header.parseUntil(key, ':') + 1

      if i >= header.len:
        return false

      i += header.skipWhiteSpace(i)
      i += header.parseUntil(value, newLine, i)

      headers[key] = value

    else:
      return false


proc parseHTTPHeader*(client: AsyncSocket, headers: var StringTableRef): bool =
  ## parse HTTP header
  parseHTTPHeader(header):
    if not client.readLine(header):
      header = ""


proc parseHTTPHeader*(client: Socket, headers: var StringTableRef): bool =
  ## parse HTTP header
  parseHTTPHeader(header):
    client.readLine(header)


# This proc should not be needed once sockets.nim is fixed
proc select_c*(rsocks: var seq[Socket], timeout = -1): int =
  var rd = rsocks
  result = sockets.select(rd, timeout)

  var i = 0
  var L = rsocks.len
  while i < L:
    if rsocks[i] in rd:
      rsocks[i] = rsocks[L-1]; dec(L)
    else: inc(i)
  setLen(rsocks, L)