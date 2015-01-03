{.experimental.}

import macros

type StackPtr*[T] = object
    get: ptr T

method destroy*[T](obj: var StackPtr[T]) {.override.} =
    dealloc(obj.get)

    when isMainModule: echo "Destroyed"

macro `.`*[T](left: StackPtr[T], right: expr): expr {.immediate.} =
    result = parseExpr($left & ".get." & right.strVal)

template new*(obj: expr): expr =
    # Allocate memory
    var heapRef = cast[ptr type(obj)](alloc(sizeof(type(obj))))

    block:
        # TODO: Replace this with more efficient mechanism; destruct
        # the object construction into multiple assignments

        # Copy object onto heap
        var stackRef = obj
        copyMem(heapRef, addr stackRef, sizeof(stackRef))

    # Create container
    StackPtr[type(obj)](get: heapRef)

when isMainModule:

    type MyType = object
        id: int
        value: int

    proc test2(obj: StackPtr[MyType]): string =
        $obj.value

    proc test1 =
        var item = new MyType(id: 5, value: 15)
        echo item.id
        echo item.test2

    test1()