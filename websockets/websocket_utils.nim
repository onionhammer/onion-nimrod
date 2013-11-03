##Imports
import sockets, asyncio, strtabs, parseutils, sha1


##Types
type EWebSocket* = object of EIO


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


proc parseHTTPHeader*(client: PAsyncSocket, headers: var PStringTable): bool =
  ## parse HTTP header
  parseHTTPHeader(header):
    if not client.readLine(header):
      header = ""

proc parseHTTPHeader*(client: TSocket, headers: var PStringTable): bool =
  ## parse HTTP header
  parseHTTPHeader(header):
    client.readLine(header)


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
  proc cpySeq(input: seq[TSocket]) : seq[TSocket] =
    result = newSeq[TSocket](input.len)
    for i in 0..input.len-1:
      result[i] = input[i]

  var rd = cpySeq(rsocks)

  result = sockets.select(rd, timeout)
  pruneSocketSet(rsocks, rd)

proc remove*[T](items: var seq[T], item: T, cmp: proc(a,b:T): bool) =
  var len = items.len - 1
  for i in 0 .. len:
    if cmp(items[i], item):
      if i < len:
        items[i] = items[i+1]
      items.setLen(len)
      break