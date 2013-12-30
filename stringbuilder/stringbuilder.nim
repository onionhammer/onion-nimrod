# Types
type
    TNode* = object
        content: cstring
        len: int

    TStringBuilder* = object of TObject
        head: seq[TNode]
        len: int

    PStringBuilder* = ref TStringBuilder


# Procedures
proc inc[A](some: var ptr A, b = 1) {.nostackframe, inline.} =
    some = cast[ptr A](cast[int](some) + (b * sizeof(A)))


template add_internal(builder: PStringBuilder, content = ""): stmt {.immediate.} =
    var len = content.len

    builder.head.add TNode(
        content: content.cstring,
        len: len
    )

    inc(builder.len, len)


proc add*(builder: PStringBuilder, content = "") {.nostackframe, inline.} =
    add_internal(builder, content)


proc stringbuilder*(content = ""): PStringBuilder =
    new(result)
    result.head = newSeq[TNode]()
    add(result, content)


proc `$`*(builder: PStringBuilder): string =
    result = newString(builder.len)
    var address = addr result[0]

    for next in builder.head:
        # Copy source to destination
        copymem(
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
    var result = stringbuilder("");
    result.add("line 1")
    result.add("line 2")
    result.add("line 3")

    echo($result)
    assert($result == "line 1line 2line 3")

    # Mock Data
    var data = newSeq[string]()
    for i in 0.. 10000:
        data.add("How can I keep track of how long these amazingly long strings are!:" & $i & "\n")

    # Benchmark setup
    template bench(name, operation: stmt): stmt =
        const times = 1000
        let start   = cpuTime()
        for i in 0.. < times:
            operation
        let duration = cpuTime() - start
        echo "$1 Operation took $2s" % [ name, duration.formatFloat(precision=4) ]

    when true:
        bench("String Concatenation"):
            var result = ""
            for line in data:
                result.add(line)

        bench("StringBuilder Concatenation"):
            var result = stringbuilder("");
            for line in data:
                result.add(line)
            discard $result
