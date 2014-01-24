## Nimrod HTTP server powered by LibUV

# C - Imports
{.passl: "-L."}
{.passl: "-l uv"}
{.passc: "-I include"}

when defined(windows):
    {.passl: "-lws2_32"}
    {.passl: "-lPsapi"}
    {.passl: "-lIPHLPAPI"}

# Imports
import strtabs, strutils, parseutils

# Compile C server
{.compile: "nimuv.c".}

# Types
type
    PClient = ptr object

    TUVRequest* = ref object
        client: PClient        ## Underlying nimUV client reference
        length*, read: int     ## Length & number of bytes read for request
        reqMethod*: string     ## Request method. GET or POST.
        path*, query*: string  ## path and query the client requested
        headers*: PStringTable ## headers with which the client made the request
        body*: string          ## only set with POST requests
        ip*: string            ## ip address of the requesting client
        port*: uint16          ## port of the requesting client

    THeaderParseResult = enum
        HeaderParseOK, HeaderMultiPart, HeaderInvalid


# Fields
var handleResponse* = proc(s: TUVRequest) = nil
const wwwNL*        = "\r\L"
const MAX_READ      = 10 * (1024 * 1024) # 10 Megabytes


# Procedures
proc start_server(ip: cstring, port: cint) {.nodecl, importc.}


proc end_response(client: PClient) {.nodecl, importc.}


proc send_response(client: PClient, buffer: cstring) {.nodecl, importc.}


proc parse_request(request: var TUVRequest, reqBuffer: cstring, length: int): THeaderParseResult =
    ## Parse path & headers for request
    var index  = 0
    var header = newString(length)
    copyMem(addr header[0], reqBuffer, length)

    # Parse req method & path
    var reqMethod, path, version: string

    inc index, header.parseUntil(reqMethod, ' ', index) + 1
    inc index, header.parseUntil(path, ' ', index) + 1
    inc index, header.parseUntil(version, {'\r', '\L'}, index)
    inc index, header.skipUntil('\L', index) + 1

    # Check req method
    reqMethod = reqMethod.toUpper
    case reqMethod:
    of "GET", "POST": result = HeaderParseOK
    else: return HeaderInvalid

    request.headers   = newStringTable(modeCaseInsensitive)
    request.reqMethod = reqMethod

    # Retrieve query string
    var pathIndex = 0
    inc pathIndex, path.parseUntil(request.path, '?', pathIndex) + 1
    request.query = path.substr(pathIndex)

    # Parse header
    var key, value: string
    while index < length:
        # Parse until ":"
        inc index, header.parseUntil(key, {':', '\r', '\L'}, index) + 1
        if key.len != 0:
            inc index, header.skipWhitespace(index)
            inc index, header.parseUntil(value, {'\r', '\L'}, index)
            inc index, header.skipUntil('\L', index)
        else:
            inc index, header.skipUntil('\L', index) + 1
            break

        request.headers[key] = value
        inc index

    # Rest of request is the body
    request.body = header.substr(index, length)
    request.read = request.body.len

    # Check if there is any more information to receive
    # if so, gc_ref the UVRequest
    var contentLength: int
    var contentLength_s = request.headers["content-length"]
    if contentLength_s != nil and
       contentLength_s.parseInt(contentLength) > 0 and
       request.read < contentLength:
       # Request has more information that must be read
       request.read   = request.body.len
       request.length = contentLength
       return HeaderMultiPart


proc http_readheader(client: PClient, reqBuffer, ip: cstring,
    port: cushort, nread: cint): TUVRequest {.cdecl, exportc.} =
    ## Build TUVRequest/client object
    var request  = TUVRequest(client: client)
    request.ip   = $ip
    request.port = port.uint16

    case parse_request(request, reqBuffer, nread)
    of HeaderParseOK:
        handleResponse(request)

    of HeaderMultiPart:
        # Continue reading from input
        gc_ref(request)
        return request

    else:
        # gc_unref the UVRequest
        send_response(client, "Unrecognized request")
        end_response(client)


proc http_continue(request: TUVRequest, reqBuffer: cstring, nread: cint): bool {.cdecl, exportc.} =
    ## Continue request
    inc request.read, nread

    if request.read > MAX_READ:
        end_response(request.client)
        return false

    # All bytes from request have been read, append to body
    var bodyLength = request.body.len
    var newLength  = min(request.read, request.length)

    request.body.setLen(newLength)
    copyMem(addr request.body[bodyLength], reqBuffer, nread)

    if request.read >= request.length:
        gc_unref(request)
        handleResponse(request)
        return false

    return true


proc http_end(request: TUVRequest) {.cdecl, exportc.} =
    ## Unreference the request - it was cancelled or broken
    gc_unref(request)


template `&=`*(result, value): expr {.immediate.} =
    ## Send data back to client
    add(result, value)


proc add*(result: TUVRequest, value: string) =
    ## Send data back to client
    send_response(result.client, value)


proc close*(request: TUVRequest) =
    ## Close the incoming request
    end_response(request.client)


proc run*(ip = "0.0.0.0", port = 8080) =
    ## Run the NIM UV Server
    start_server(ip.cstring, port.cint)


# Tests
when isMainModule:

    proc onRequest(result: TUVRequest) =
        result.add(result.headers["cache-control"] & "\r\n")
        result.add("hello world\r\n")
        result.add("i like cheese")
        result.close()

    handleResponse = onRequest

    run()