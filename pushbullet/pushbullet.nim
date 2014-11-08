## Pushbullet API for Nim
when not defined(ssl):
    {.define: ssl.}

# Imports
import strutils, json, future, asyncdispatch, httpclient, strtabs


# Fields
const root_path   = "https://api.pushbullet.com/v2/"
var token: string = nil


# Types
type
    PushType* = enum
        Note, Link, Address, Checklist

    PushRequest* = object
        device*: string
        title*: string
        body*: string
        case kind*: PushType
        of Note: nil
        of Link:
            url*: string
        of Address:
            name*: string
            address*: string
        of Checklist:
            items*: seq[string]

    HeaderPair = tuple[key, value: string]


# Procedures
proc `%`(kind: PushType): JsonNode =
    ## Convert a PushType kind to JSON node
    return case kind:
    of Note:      %"note"
    of Link:      %"link"
    of Address:   %"address"
    of Checklist: %"checklist"

proc setToken*(value: string) =
    ## Set the API token
    token = value

proc getToken: string =
    ## Get the API token
    assert token != nil, "Token is currently empty"
    token

template `.`*(js: JsonNode, field: string): JsonNode =
    ## Automatically retrieve json node
    js[field]

proc getRequest(path: string): Future[JsonNode] {.async.} =
    ## GET request to pushbullet API
    let client = newAsyncHttpClient()
    client.headers["Authorization"] = "Bearer " & getToken()

    let response = await client.get(root_path & path)

    return parseJson(response.body)

proc postRequest(path: string, data: JsonNode): Future[JsonNode] {.async.} =
    ## POST request to pushbullet API
    let body   = $data
    let client = newAsyncHttpClient()
    client.headers["Authorization"]  = "Bearer " & getToken()
    client.headers["Content-Type"]   = "application/json"
    client.headers["Content-Length"] = $body.len

    let response = await client.request(
        root_path & path, httpPOST, body)

    return parseJson(response.body)

proc me*: Future[JsonNode] {.async.} =
    ## Get information about the current user.
    return await getRequest("users/me")

proc devices*: Future[JsonNode] {.async.} =
    ## List or create devices that can be pushed to.
    return (await getRequest("devices")).devices

proc contacts*: Future[JsonNode] {.async.} =
    ## List your Pushbullet contacts.
    return (await getRequest("contacts")).contacts

proc subscriptions*: Future[JsonNode] {.async.} =
    ## Channels that the user has subscribed to.
    return (await getRequest("subscriptions")).subscriptions

proc push*(args: PushRequest): Future[JsonNode] {.async, discardable.} =
    ## Push to a device/user or list existing pushes.
    var info = %[
        ( "type", %args.kind )
    ]

    if args.device != nil:
        info.add("device_iden", %args.device)

    if args.title != nil and args.kind in [ Note, Link, Checklist ]:
        info.add("title", %args.title)

    case args.kind
    of Note:
        if args.body != nil:
            info.add("body", %args.body)
    of Link:
        if args.body != nil:
            info.add("body", %args.body)
        if args.url != nil:
            info.add("url", %args.url)
    of Address:
        if args.name != nil:
            info.add("name", %args.name)
        if args.address != nil:
            info.add("address", %args.address)
    of Checklist:
        if args.items != nil:
            info.add("items", %args.items.map(proc (x: string): JsonNode = %x))

    return await postRequest("pushes", info)


when isMainModule:
    ## App interface of library

    # Imports
    import os, parseopt2, uri

    # Fields
    const file_name = "token.cfg"
    let file_path   = joinPath(getAppDir(), file_name)

    # Procedures
    proc tryParseInt(value: string): int =
        try:
            return value.parseInt()
        except:
            return -1

    proc tryParseUrl(value: string): string =
        var uri = parseUri(value)
        if uri.scheme != "":
            return value
        return nil

    proc getStoredToken: string =
        var file: TFile
        result =
            if file.open(file_path): file.readLine()
            else: nil
        finally: file.close()

    proc setStoredToken =
        file_path.writeFile(token)

    proc main {.async.} =
        # Ensure we have API Token
        token = getStoredToken()

        while token == nil:
            # Request token from user
            stdout.write("API Token: ")
            setToken stdin.readLine()
            setStoredToken()

        # Parse command line
        var deviceIndex  = -1
        var note: string = nil
        var url: string  = nil

        for kind, key, value in getopt():
            case kind:
            of cmdArgument:
                if deviceIndex == -1:
                    # Parse as device index
                    deviceIndex = tryParseInt(key)
                    if deviceIndex >= 0: continue

                if url == nil:
                    # Parse as URL
                    url = tryParseUrl(key)
                    if url != nil: continue

                if note == nil:
                    # Treat as note
                    note = key
            else:
                # Do nothing
                discard

        var args = PushRequest(kind: Note)
        var allDevices: JsonNode

        if deviceIndex >= 0:
            # Retrieve device
            allDevices = await devices()
            if allDevices.len > deviceIndex:
                args.device = allDevices[deviceIndex].iden.str
            else:
                echo "Invalid device index"; return

        if url != nil:
            args.kind  = Link
            args.url   = url
            args.title = note
        elif note != nil:
            args.title = "Note"
            args.body  = note
        else:
            if allDevices == nil:
                allDevices = await devices()

            var i = 0
            echo "Devices:"
            for device in allDevices:
                echo "[$1] = $2" % [$i, device.nickname.str]
                inc i
            return

        # Transmit
        echo "Pushed to: ", (await push(args)).receiver_email

    waitFor main()