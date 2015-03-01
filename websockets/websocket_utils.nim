##Imports
import sockets, asyncio, strtabs, parseutils, sha1


##Types
type EWebSocket* = object of IOError


## Websocket utility procedures
proc websocketError*(msg: string) {.noreturn.} =
  ## Raises an EWebSocket exception with message `msg`.
  var e: ref EWebSocket
  new(e)
  e.msg = msg
  raise e


template parseHTTPHeader(header: expr, readline: stmt): stmt {.immediate.} =
  var header = ""
  readline

  if header == "":
    return false

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
      i += header.parseUntil(value, {'\c', '\L'}, i)
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