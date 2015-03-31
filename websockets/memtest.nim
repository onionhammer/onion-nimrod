import asyncio, sockets
import threadpool, locks
import os, terminal, strutils, times

const PASS_CONNECTIONS = 100_000

var glock: TLock
var numConnections {.guard: glock.} = 0
var srvChannel = TChannel[string]()

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
    var maxMem   = 0
    var last     = 0.0

    while nConnect < PASS_CONNECTIONS:
        var client = socket()
        client.connect("", Port(8080))
        client.send("hello world\r\L")
        client.close()

        inc nConnect
        {.locks: [ glock ].}:
            numConnections = nConnect

            # Write output to screen
            var next = cpuTime()
            if next - last > 0.05 or nConnect == PASS_CONNECTIONS:
                last = next

                # Clear the screen
                eraseScreen()
                setCursorPos 0,0

                # Read server memory
                var serverMem = ""
                while srvChannel.peek() > 0:
                    serverMem = srvChannel.recv()

                let occupied = getOccupiedMem()
                if occupied > maxMem: maxMem = occupied

                echo "Client Memory: ", occupied.formatSize(),
                     " max: ", maxMem.formatSize()
                echo "Server Memory: ", serverMem
                echo "Clients: ", numConnections, " out of ", PASS_CONNECTIONS


when isMainModule:
    srvChannel.open()
    var ws = open()
    ws.dispatcher = newDispatcher()
    ws.dispatcher.register(ws.socket)

    # Run tests
    spawn runClients()

    while ws.dispatcher.poll():
        {.locks: [ glock ].}:
            srvChannel.send(getOccupiedMem().formatSize())
            if numConnections == PASS_CONNECTIONS:
                break

    sync()
    srvChannel.close()

