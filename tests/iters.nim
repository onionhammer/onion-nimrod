from sequtils import toSeq

type IEnumerable*[T] = object of RootObj
  pos: int
  data: seq[T]

iterator items*[T](it: var IEnumerable[T]): T =
    mixin current, moveNext
    while moveNext(it):
        yield current(it)

proc moveNext*(it: var IEnumerable): bool =
    if it.pos < it.data.len - 1:
        inc it.pos
        return true

proc current*[T](it: var IEnumerable[T]): T =
    it.data[it.pos]

proc asEnumerable*[T](it: seq[T]): IEnumerable[T] =
    IEnumerable[T](pos: -1, data: it)

proc asEnumerable*[T](it: openarray[T]): IEnumerable[T] =
    var items = newSeq[T](it.len)
    for i in 0.. < it.len:
        items[i] = it[i]

    IEnumerable[T](pos: -1, data: items)

when isMainModule:
    var x = @[4, 5, 6].asEnumerable()

    for t in x:
        echo t; break

    for t in x:
        echo t, " <-"
