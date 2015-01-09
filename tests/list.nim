import memory, strutils, future

type
    Node*[T] = object
        item: T
        next: ref Node[T]

    List*[T] = object
        head: ref Node[T]
        tail: ref Node[T]

proc `$`*[T](node: ref Node[T]): string =
    if node != nil: $(node[])
    else: ""

proc `$`*[T](list: ref List[T]): string =
    result = ""
    for i in list:
        result &= $(i.item)

        if i != list.tail:
            result &= ","

iterator items*[T](list: ref List[T]): ref Node[T] =
    var node = list.head
    while node != nil:
        yield node
        node = node.next

proc add*[T](list: ref List[T], value: T) =
    var node = new Node[T](item: value)

    if list.head == nil:
        list.head = node
        list.tail = node
    else:
        list.tail.next = node
        list.tail = node

when isMainModule:

    proc test1 =
        var list = new List[int]()

        for i in 1..10:
            list.add i

        echo list

    test1()