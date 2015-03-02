import asyncio, sockets
import threadpool, locks, os, terminal, strutils

type WebSocket = ref object
    socket: AsyncSocket
    dispatcher: Dispatcher

var glock: TLock
var numConnections {.guard: glock.} = 0
const passConnections = 10_000

proc handleAccept(server: AsyncSocket): AsyncSocket =
    new(result)
    accept(server, result)

proc open: WebSocket =
    new(result)

    # Bind socket
    result.socket = asyncSocket()
    setSockOpt(result.socket, OptReuseAddr, true)
    bindAddr(result.socket, Port(8080), "")

    var ws = result
    result.socket.handleAccept = proc(s: AsyncSocket) =
        var socket = handleAccept(s)

        socket.handleRead = proc(socket: AsyncSocket) {.closure, gcsafe.} =
            # TODO - Read some data

            # Close the connection
            socket.close()
            # socket.unregister()

        ws.dispatcher.register(socket)

    # Start listening
    listen(result.socket)

proc runClients =
    var nConnect = 0
    while nConnect < passConnections:
        var client = socket()
        client.connect("", Port(8080))
        client.send("hello world")
        client.close()
        inc nConnect
        {.locks: [ glock ].}:
            numConnections = nConnect
        sleep(1)

when isMainModule:
    var ws = open()
    ws.dispatcher = newDispatcher()
    ws.dispatcher.register(ws.socket)

    # Run tests
    spawn runClients()

    var maxOccupied = 0
    while ws.dispatcher.poll():
        eraseScreen()
        setCursorPos 0,0

        {.locks: [ glock ].}:
            var occupied = getOccupiedMem()
            if occupied > maxOccupied: maxOccupied = occupied

            echo "Memory: ", occupied.formatSize(),
                 " max: ", maxOccupied.formatSize()
            echo "Clients: ", numConnections, " out of ", passConnections

            if numConnections == passConnections:
                break

    sync()
