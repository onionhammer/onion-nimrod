import sockets, asyncio


type TWebSocketServer = object
  asyncServer: PAsyncSocket
  dispatcher: PDispatcher


var ws: TWebSocketServer


proc onClientRead(s: PAsyncSocket) =
  var line = ""
  discard s.readLine(line)
  s.send("error")
  s.close()


proc handleAccept(server: PAsyncSocket) =
  # accept incoming connection
  var socket: PAsyncSocket
  new(socket)

  socket.handleRead = onClientRead
  accept(server, socket)


proc open*(address = "127.0.0.1", port = TPort(8080)) =
  # open a socket server
  ws.asyncServer = asyncSocket()
  bindAddr(ws.asyncServer, port, address)
  listen(ws.asyncServer)

  ws.asyncServer.handleAccept = handleAccept


proc register*(dispatcher: PDispatcher, ws: var TWebSocketServer) =
  dispatcher.register(ws.asyncServer)
  ws.dispatcher = dispatcher


block main:
  open()

  let dispatch = newDispatcher()
  dispatch.register(ws)

  while dispatch.poll(): 
    echo "memory: ", getOccupiedMem()

  # Now open leak.html in a browser