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
                newNimNode(nnkRefTy).add(typeName.ident),
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
    get: ptr T

method destroy*[T](obj: var StackPtr[T]) {.override.} =
    dealloc(obj.get)
    when isMainModule: echo "Destroyed"

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
    echo "Test `new`:"

    type MyType = object
        value: int
        other: ref MyType

    proc square(self: MyType|ref MyType): auto =
        if self.other != nil:
            self.other.value * self.other.value
        else:
            self.value * self.value

    proc test1 =
        var item1 = MyType(value: 5)     # Creates: MyType
        var item2 = new MyType(value: 5) # Creates: ref MyType
        var item3 = new MyType(other: new MyType(value: 7))

        assert(item2 != nil)
        assert(item1.value == 5)
        assert(item2.value == 5)

        echo item1.square
        echo item2.square
        echo item3.square

        assert(declared(i) == false, "`i` leaked to main scope")

    test1()

# Test `stack`
when isMainModule:
    echo "Test `stack`:"

    type MyObject = object
        value: int

    proc test2 =
        var test1 = stack MyObject(value: 5)

        echo test1.value

    test2()