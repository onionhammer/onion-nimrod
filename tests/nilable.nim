## nilable.nim
##
## Utilities for dealing with nil values and nilable types

import parseutils

type INilable* = generic x
    isNil(x) is bool

template `?.`*(x: INilable, y: expr): expr =
    ## Whole expression becomes nil if left-side of dot is nil
    if isNil(x): nil
    else: x.y

template `??`*(x, y: INilable): expr =
    ## Specify a default value if left-side is nil
    if isNil(x): y
    else: x

proc isNilOrWhitespace(x: string): bool =
    ## Return true if the string is nil or contains only whitespace
    if x == nil or x == "": return true
    return x.skipWhitespace() == x.len

template nilify(x: string): string =
    ## Returns a nil string if the string is only empty characters
    if x.isNilOrWhitespace: nil
    else: x

when isMainModule:

    type TestType = ref object
        value: string

    proc `$`(t: TestType): string = t.value

    var t = TestType(value: "Hello")
    var x: TestType

    assert((x ?? t) != nil)
    assert((x?.value) == nil)

    x = TestType(value: "")
    assert((x.value) != nil)
    assert((x.value.nilify) == nil)
    assert "hello".nilify == "hello"

    var d: string
    assert d.nilify == nil

    assert "  ".isNilOrWhitespace()
    assert "  ".nilify == nil
    assert((" ".nilify ?? "hello") == "hello")
