import terminal, asyncdispatch


template loop*(body: stmt): stmt =
    while true: body

template emit(code: static[string]): stmt =
    {.emit: code.}

type winsize = object
    ws_row:    int16 # rows, in characters
    ws_col:    int16 # columns, in characters
    ws_xpixel: int16 # horizontal size, pixels
    ws_ypixel: int16 # vertical size, pixels

emit: "#import <sys/ioctl.h>"
emit: "#import <unistd.h>"

proc getWinSize: winsize = {.emit: """
    ioctl(STDOUT_FILENO, TIOCGWINSZ, &`result`);
    """.}

# Get cols
var termsize = getWinSize()

eraseScreen()
setCursorPos(2, 5)

proc hr =
    echo()
    for i in 1 .. termsize.ws_col:
        stdout.write("=")
    echo()
    echo()

for i in 0 .. 5:
    setCursorXPos(5)
    echo i, " Hello world!"

hr()

for i in 0 .. 5:
    setCursorXPos(5)
    echo i, " Hello world!"
echo()

loop:
    var i = stdin.readline()
    if i == "break": break