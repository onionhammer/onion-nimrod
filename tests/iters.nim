iterator items*[T, K](it: var T): K =
    mixin current, moveNext
    while moveNext(it):
        yield current(it)

type List*[T] = object of RootObj
  pos: int
  data: seq[T]

method moveNext*(it: var List): bool =
    if it.pos < it.data.len - 1:
        inc it.pos
        return true

method current*(it: var List): auto =
    it.data[it.pos]

proc asList*[T](it: seq[T]): auto =
    List[T](pos: -1, data: it)

proc asList*[T](it: openarray[T]): auto =
    var items = newSeq[T](it.len)
    for i in 0.. < it.len:
        items[i] = it[i]

    List[T](pos: -1, data: items)

when isMainModule:
    var x = @[4, 5, 6].asList()

    for t in x:
        echo t; break

    for t in x:
        echo t, " <-"
