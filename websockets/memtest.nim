import asyncio, sockets
import threadpool, locks, os, terminal, strutils

const PASS_CONNECTIONS = 10_000

var glock: TLock
var numConnections {.guard: glock.} = 0

type WebSocket = ref object
    socket: AsyncSocket
    dispatcher: Dispatcher

proc open: WebSocket =
    new(result)

    # Bind socket
    result.socket = asyncSocket()
    setSockOpt(result.socket, OptReuseAddr, true)
    bindAddr(result.socket, Port(8080), "")

    var ws = result
    result.socket.handleAccept = proc(server: AsyncSocket) =
        var client: AsyncSocket
        new(client)
        accept(server, client)

        client.handleRead = proc(socket: AsyncSocket) =
            # TODO - Read some data

            # Close the connection
            socket.close()

        ws.dispatcher.register(client)

    # Start listening
    listen(result.socket)

proc runClients =
    var nConnect = 0
    while nConnect < PASS_CONNECTIONS:
        var client = socket()
        client.connect("", Port(8080))
        client.send("hello world\r\L")
        client.close()
        inc nConnect
        {.locks: [ glock ].}:
            numConnections = nConnect
        sleep(100)

when isMainModule:
    var ws = open()
    ws.dispatcher = newDispatcher()
    ws.dispatcher.register(ws.socket)

    # Run tests
    spawn runClients()

    var maxMem = 0
    while ws.dispatcher.poll():
        eraseScreen()
        setCursorPos 0,0

        {.locks: [ glock ].}:
            let occupied = getOccupiedMem()
            if occupied > maxMem: maxMem = occupied

            echo "Memory: ", occupied.formatSize(),
                 " max: ", maxMem.formatSize()
            echo "Clients: ", numConnections, " out of ", PASS_CONNECTIONS

            if numConnections == PASS_CONNECTIONS:
                break

    sync()
