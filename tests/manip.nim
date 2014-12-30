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

when isMainModule:

    type IOStream = object of Stream

    method `<<`[T](dest: IOStream, src: T): IOStream {.discardable.} =
        stdout.write(src)
        return dest

    method `>>`[T](src: IOStream, dest: var T) =
        # TODO - Implement me
        # echo stdin.readBuffer(addr dest, sizeof(T))
        discard

    const endl = '\L'

    let
        cout* = IOStream()
        cin*  = IOStream()

    var n: int
    cout << 25 << endl << "Grats\L"
    cin >> n
    cout << n << endl