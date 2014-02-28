# Types
type
    TNode = object
        content: cstring
        len: int

    PStringBuilder* = ref object
        head: seq[TNode]
        len*: int


# Procedures
proc inc[A](some: var ptr A, b = 1) {.inline.} =
    some = cast[ptr A](cast[int](some) + (b * sizeof(A)))


template add_internal(builder: PStringBuilder, content: string): stmt {.immediate.} =
    builder.head.add TNode(
        content: content,
        len:     content.len
    )

    inc(builder.len, content.len)


proc add*(builder: PStringBuilder, content = "") =
    add_internal(builder, content)


proc `&=`*(builder: PStringBuilder, content = "") =
    add_internal(builder, content)


proc stringbuilder*(content = ""): PStringBuilder =
    new(result)
    result.head = newSeq[TNode]()
    if content != "":
        add_internal(result, content)


proc `$`*(builder: PStringBuilder): string =
    result      = newString(builder.len)
    var address = addr result[0]

    for next in builder.head:
        # Copy source to destination
        copyMem(
            address,
            next.content,
            next.len
        )

        inc(address, next.len)


# Tests
when isMainModule:

    # Imports
    import strutils, times

    # test stringbulder
    var result = stringbuilder();
    result.add("line 1")
    result.add("line 2")
    result.add("line 3")

    echo($result)
    assert($result == "line 1line 2line 3")

    # Value
    # Mock Data
    var data = newSeq[string]()
    for i in 0.. 800:
        data.add "test!" & $i
        # data.add("How can I keep track of how long these amazingly long strings are!:" & $i & "\n")

    # Benchmark setup
    template bench(name, operation: stmt): stmt =
        const times = 100000
        let start   = cpuTime()
        for i in 0.. < times:
            operation
        let duration = cpuTime() - start
        echo "$1 Operation took $2s" % [ name, duration.formatFloat(precision=4) ]

    when true:
        var
            str: string
            sb: PStringBuilder

        bench("String Concatenation"):
            str = ""
            for line in data:
                str &= line
            discard str

        bench("StringBuilder Concatenation"):
            sb = stringbuilder("")
            for line in data:
                sb &= line
            discard $sb

        assert($sb == str)
        echo "strings matched"
