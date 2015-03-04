import strutils

type Stream* = object of RootObj
    length*: int
    position*: int

method `<<`[T](dest: Stream, src: T): Stream {.discardable.} =
    ## Write to stream
    return dest

method `>>`[T](src: Stream, dest: var T) =
    ## Read from stream
    discard

method close(this: Stream) =
    discard

type IOStream = object of Stream

method `<<`[T](dest: IOStream, src: T): IOStream {.discardable.} =
    stdout.write(src)
    return dest

method `>>`(src: IOStream, dest: var string) =
    dest = stdin.readline()

method `>>`(src: IOStream, dest: var int) =
    dest = stdin.readline().parseInt()

method `>>`(src: IOStream, dest: var char) =
    dest = stdin.readchar()

const endl* = '\L'

let
    cout* = IOStream()
    cin*  = IOStream()

when isMainModule:
    var n: string
    cout << 25 << endl << "Grats\L"
    cin >> n
    cout << n << endl