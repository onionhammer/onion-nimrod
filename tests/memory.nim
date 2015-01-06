{.experimental.}

import macros

# `New` macro
proc makeRef(obj: PNimrodNode): PNimrodNode {.compiletime.} =
    var typeName: string
    var assignments = newSeq[PNimrodNode]()

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
                newDotExpr(ident"i", left),
                right
            )
        else: discard

    # Compose resulting AST
    var resultExpr = newStmtList(
        newNimNode(nnkVarSection).add(
            newNimNode(nnkIdentDefs).add(
                ident"i",
                parseExpr("ref " & typeName),
                newEmptyNode()
            )
        ),
        parseExpr("new(i)")
    )

    resultExpr.add assignments
    resultExpr.add ident"i"

    return newStmtList(
        newBlockStmt(newEmptyNode(), resultExpr))

macro new*(obj: expr{nkObjConstr|nkCall}): expr =
    makeRef(obj)

# `Stack` macro
type StackPtr*[T] = object
    get*: ptr T

method destroy*[T](obj: var StackPtr[T]) {.override.} =
    dealloc(obj.get)
    when isMainModule: echo "Destroyed"

converter unwrap[T](obj: var StackPtr[T]): ptr T = obj.get
converter unwrap[T](obj: var StackPtr[T]): T = obj.get[]

macro `.`*[T](left: StackPtr[T], right: expr): expr {.immediate.} =
    result = parseExpr($left & ".get." & right.strVal)

proc makePtr(obj: PNimrodNode): PNimrodNode {.compiletime.} =
    var typeName: string
    var assignments = newSeq[PNimrodNode]()

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
                newDotExpr(ident"i", left),
                right
            )
        else: discard

    # Compose resulting AST
    var resultExpr = newStmtList(
        newNimNode(nnkVarSection).add(
            newNimNode(nnkIdentDefs).add(
                ident"i",
                newEmptyNode(),
                parseExpr("cast[ptr " & typeName & "](alloc(sizeof(" & typeName & ")))"),
            )
        )
    )

    resultExpr.add assignments
    resultExpr.add parseExpr("StackPtr[" & typeName & "](get:i)")

    return newStmtList(
        newBlockStmt(newEmptyNode(), resultExpr))

macro stack*(obj: expr{nkObjConstr|nkCall}): expr =
    makePtr(obj)

# Test `new`
when isMainModule:
    type MyType = object
        value: int
        other: ref MyType

when isMainModule:
    echo "Test `new`:"

    proc square(self: MyType|ref MyType): auto =
        if self.other != nil:
            self.other.value * self.other.value
        else:
            self.value * self.value

    proc test1 =
        let item1 = MyType(value: 5)     # Creates: MyType
        var item2 = new MyType(value: 5) # Creates: ref MyType
        let item3 = new MyType(other: new MyType(value: 7))

        assert(item2 != nil)
        assert(item1.value == 5)
        assert(item2.value == 5)

        echo item1.square
        echo item2.square
        echo square(item3)

        assert(declared(i) == false, "`i` leaked to main scope")

    test1()

    proc test3 =
        var item1 = new MyType(value: 5)

    test3()

# Test `stack`
when isMainModule:
    echo "Test `stack`:"

    proc cube(self: MyType): auto =
        self.value * self.value * self.value

    proc test2 =
        var test1 = stack MyType(value: 5)
        assert(test1.get != nil)
        assert(declared(i) == false, "`i` leaked to main scope")
        assert(declared(s) == false, "`s` leaked to main scope")

        echo test1.value
        echo test1.cube
        echo cube(test1)

    test2()