proc CPP {.importcpp.}

import memory, strutils

type
    Node*[T] = object
        item: T
        next: ref Node[T]

    List*[T] = object
        head: ref Node[T]
        tail: ref Node[T]
        length: int

    IList*[T] = List[T] | ref List[T]

proc `$`*(node: ref Node): string =
    if node != nil: $(node.item)
    else: ""

proc `$`*(list: IList): string =
    result = ""
    for i in list:
        result &= $i

        if i != list.tail:
            result &= ", "

proc len*(list: IList): int =
    list.length

proc `[]`*[T](list: IList[T], index: int): ref Node[T] =
    var i = 0
    for node in list:
        if i == index: return node
        inc(i)

    raise newException(IndexError, "Index out of range")

iterator items*[T](list: IList[T]): ref Node[T] =
    var node = list.head
    while node != nil:
        yield node
        node = node.next

proc add*[T](list: var IList, value: T) =
    var node = new Node[T](item: value)

    if list.head == nil:
        list.head = node
        list.tail = node
    else:
        list.tail.next = node
        list.tail = node

    inc(list.length)

when isMainModule:

    proc test1 =
        var list = new List[int]()

        for i in 1..10:
            list.add i

        echo list.len
        echo list
        echo list[4]

    test1()