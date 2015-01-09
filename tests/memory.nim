{.experimental.}

import macros

proc deconstruct(obj: PNimrodNode):
    tuple[name: string, ast: seq[PNimrodNode], i: PNimrodNode] {.compiletime.} =

    var typeName: string
    var assignments = newSeq[PNimrodNode]()
    var iVar = genSym(nskVar)

    for i in obj.children:
        case i.kind
        of nnkIdent:
            typeName = $i
        of nnkExprColonExpr:
            var left, right: PNimrodNode
            for value in i.children:
                if left == nil: left  = value
                else:           right = value
            assignments.add newAssignment(
                newDotExpr(iVar, left),
                right
            )
        else: discard

    return (name: typeName, ast: assignments, i: iVar)

# `New` macro
proc makeRef(obj: PNimrodNode): PNimrodNode {.compiletime.} =
    var (typeName, assignments, iVar) = deconstruct(obj)

    # Compose resulting AST
    result = newStmtList(
        newNimNode(nnkVarSection).add(
            newNimNode(nnkIdentDefs).add(
                iVar,
                parseExpr("ref " & typeName),
                newEmptyNode()
            )
        ),
        newCall(ident"new", iVar)
    )

    result.add assignments
    result.add iVar

macro new*(obj: expr{nkObjConstr|nkCall}): expr =
    makeRef(obj)

# `Auto` macro
type AutoPtr*[T] = object
    get: ptr T

proc makePtr(obj: PNimrodNode): PNimrodNode {.compiletime.} =
    var (typeName, assignments, iVar) = deconstruct(obj)

    # Compose resulting AST
    result = newStmtList(
        newNimNode(nnkVarSection).add(
            newNimNode(nnkIdentDefs).add(
                iVar,
                newEmptyNode(),
                parseExpr("cast[ptr " & typeName & "](" & typeName & ".sizeof.alloc)")
            )))

    result.add assignments
    result.add newNimNode(nnkObjConstr).add(
            parseExpr("AutoPtr[" & typeName & "]"),
            newNimNode(nnkExprColonExpr).add(
                ident"get", iVar
            ))

converter unwrap*[T](obj: var AutoPtr[T]): ptr T = obj.get

converter unwrap*[T](obj: var AutoPtr[T]): T = obj.get[]

proc getPtr*[T](obj: AutoPtr[T]): ptr T = obj.get

method destroy*[T](obj: var AutoPtr[T]) {.override.} =
    dealloc(obj.get)
    when isMainModule: echo "Destroyed"

macro `.`*[T](left: AutoPtr[T], right: expr): expr =
    result = parseExpr($left & ".get." & right.strVal)

macro push*(obj: expr{nkObjConstr|nkCall}): expr =
    makePtr(obj)

template push*[T](obj: ptr T): AutoPtr[T] =
    AutoPtr[T](get: obj)

when isMainModule:
    type
        MyType = object
            value: int
            other: ref MyType
        IMyType = MyType|ref MyType|AutoPtr[MyType]

    proc square(self: IMyType): auto =
        if self.other != nil:
            self.other.value * self.other.value
        else:
            self.value * self.value

    proc cube(self: IMyType): auto =
        self.value * self.value * self.value

# Test `new`
when isMainModule:
    echo "Test `new`:"

    proc test1 =
        let item1 = MyType(value: 5)     # Creates: MyType
        var item2 = new MyType(value: 5) # Creates: ref MyType
        let item3 = new MyType(other: new MyType(value: 7))

        assert(item2 != nil)
        assert(item1.value == 5)
        assert(item2.value == 5)

        echo item1.square
        echo item2.square
        echo item2.cube
        echo square(item3)

    test1()

# Test `push`
when isMainModule:
    echo "Test `push`:"

    proc test2 =
        var test1 = push MyType(value: 5)
        assert(test1.get != nil)

        echo test1.value
        echo test1.square
        echo test1.cube
        echo cube(test1)

    test2()