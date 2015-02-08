import macros

proc makeRef(obj: PNimrodNode): PNimrodNode {.compiletime.} =
    var typeName: string
    var assignments = newSeq[PNimrodNode]()

    for i in obj.children:
        if i.kind == nnkIdent:
            typeName = $i
        elif i.kind == nnkExprColonExpr:
            var left, right: PNimrodNode
            for value in i.children:
                if left == nil: left = value
                else:           right = value

            var assignment = newNimNode(nnkAsgn).add(
                newNimNode(nnkDotExpr).add(
                    ident"i", left
                ),
                right
            )

            assignments.add(assignment)

    # Compose resulting AST
    var resultExpr = newStmtList()
    resultExpr.add(
        newNimNode(nnkVarSection).add(
            newNimNode(nnkIdentDefs).add(
                ident"i",
                newNimNode(nnkRefTy).add(typeName.ident),
                newNimNode(nnkEmpty)
            )
        )
    )

    resultExpr.add(parseExpr("new(i)"))
    resultExpr.add(assignments)
    resultExpr.add(ident"i")

    return newStmtList().add(
        newNimNode(nnkBlockStmt).add(newNimNode(nnkEmpty), resultExpr))

macro new*(obj: expr{nkObjConstr|nkCall}): expr =
    return makeRef(obj)

when isMainModule:
    type MyType = object
        value: int

    proc square(self: MyType|ref MyType): auto =
        self.value * self.value

    var item1 = MyType(value: 5)     # Creates: MyType
    var item2 = new MyType(value: 5) # Creates: ref MyType
    assert(item2 != nil)
    assert(item1.value == 5)
    assert(item2.value == 5)

    echo item1.square
    echo item2.square
    assert(declared(i) == false, "`i` leaked to main scope")