# UV Interface
# References:
# http://nikhilm.github.io/uvbook/index.html
# https://github.com/joyent/http-parser
# https://github.com/joyent/libuv/tree/master/samples/socks5-proxy
# webserver: https://github.com/philips/libuv-webserver
# video: http://vimeo.com/24713213 :39m
# parser: https://github.com/joyent/http-parser

# C - Imports
{.passl: "-L."}
{.passl: "-l uv"}
{.passc: "-I include"}

when defined(windows):
    {.passl: "-lws2_32"}
    {.passl: "-lPsapi"}
    {.passl: "-lIPHLPAPI"}

import parseutils

type
    TUVCallback = proc(client: PClient): cint {.cdecl.}

    UV_tcp {.importc: "uv_tcp_t", header: "uv.h".} = object
    UV_write {.importc: "uv_write_t".} = object

    TClient {.exportc: "client_t".} = object
        handle {.exportc.}: UV_tcp
        req {.exportc.}: UV_write

    PClient = ptr TClient


proc start_server(ip: cstring, port: cint) {.nodecl, importc.}

proc end_response(client: PClient) {.nodecl, importc.}

proc send_response(client: PClient, buffer: cstring) {.nodecl, importc.}

proc append_header(client: PClient, header_str: cstring) {.exportc, cdecl.} =
    var value, key: string
    var header = $header_str
    var i = 0

    inc i, header.parseUntil(key, ':', i) + 1
    inc i, header.skipWhitespace(i)
    discard header.parseUntil(value, {'\r', '\L'}, i)

include uv


# Wrapper Code
import strtabs

type
    TServer* = object
        client: PClient
        reqMethod*: string     ## Request method. GET or POST.
        path*, query*: string  ## path and query the client requested
        headers*: PStringTable ## headers with which the client made the request
        body*: string          ## only set with POST requests
        ip*: string            ## ip address of the requesting client

# Fields
var handleResponse* = proc(s: TServer) = nil

# Procedures
proc parse_header(server: var TServer, reqBuffer: cstring, length: int): bool =
    var index  = 0
    var header = $reqBuffer

    # Parse req method & path
    var reqMethod, path, version: string

    inc index, header.parseUntil(reqMethod, ' ', index) + 1
    inc index, header.parseUntil(path, ' ', index) + 1
    inc index, header.parseUntil(version, {'\r', '\L'}, index)
    inc index, header.skipWhitespace(index)

    # Check req method
    case reqMethod:
    of "GET", "POST": result = true
    else: return false

    server.headers   = newStringTable(modeCaseInsensitive)
    server.path      = path
    server.reqMethod = reqMethod

    # Parse header
    var key, value: string
    while index < length:
        # Parse until ":"
        inc index, header.parseUntil(key, {':', '\r', '\L'}, index) + 1
        inc index, header.skipWhitespace(index)
        inc index, header.parseUntil(value, {'\r', '\L'}, index)
        inc index, header.skipWhitespace(index) - 1
        server.headers[key] = value

        inc index


proc http_response(client: PClient, reqBuffer: cstring, nread: int) {.cdecl, exportc.} =
    # Build TServer/client object
    var server = TServer(client: client)

    if parse_header(server, reqBuffer, nread):
        handleResponse(server)
    else:
        send_response(client, "Unrecognized response")

    end_response(client)


template `&=`*(result, value): expr {.immediate.} =
    add(result, value)


proc add*(result: TServer, value: string) =
    send_response(result.client, value)


proc close*(s: TServer) =
    end_response(s.client)


proc run*(ip = "0.0.0.0", port = 8080) =
    start_server(ip.cstring, port.cint)


# Tests
when isMainModule:

    proc onRequest(result: TServer) =
        result.add(result.headers["cache-control"] & "\r\n")
        result.add("hello world\r\n")
        result.add("i like cheese")
        result.close()

    handleResponse = onRequest

    run()