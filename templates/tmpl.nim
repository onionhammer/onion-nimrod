import tables, parseutils, macros
import annotate

#TODO - Remove me
import os, json, marshal, strutils


# Fields
const validChars = {'a'..'z', 'A'..'Z', '0'..'9', '_'}


# Procedures
proc transform(info_string: string, result: PNimrodNode, index: var int) {.compileTime.}


proc skip_string(value: string, i: var int, strType = '"') {.compileTime.} =
    # Go ahead to next character & find end of string
    inc(i)
    while i < value.len-1:
        inc(i, value.skipUntil({'\\', strType}, i))
        break


proc parse_to_close(value: string, line: var string, read: var int, open="(", close=")", initBraces = 0) {.compileTime.} =
    ## Parse a value until all opened braces are closed, excluding strings ("" and '')
    var remainder = value.substr(read)
    var i = 0

    var open_braces = initBraces
    let diff = open.len - 1

    while i < remainder.len-1:
        var c = $remainder.substr(i, i + diff)

        if   c == open:  inc(open_braces)
        elif c == close: dec(open_braces)
        elif c == "\"":  skip_string(remainder, i)
        elif c == "'":   skip_string(remainder, i, '\'')

        if open_braces == 0: break
        else: inc(i)

    echo remainder
    line = remainder.substr(0, i - diff)
    inc(read, i)


proc check_section(value: string, node: PNimrodNode, read: var int): bool {.compileTime.} =
    ## Check for opening of a statement section %{{  }}
    inc(read)
    if value.skipWhile({'{'}, read) == 2:
        # Parse value until colon
        var sub: string
        var sub_read = value.parseUntil(sub, ':', start=read)

        # Generate body of statement
        var body_string: string

        # body_string = value.substr(read + sub_read + 1)
        read = read + sub_read + 1

        value.parse_to_close(body_string, read, open="{{", close="}}", 1)

        # TODO - Replace statement list with parsed remainder
        var i    = 0
        var body = newStmtList()
        transform(body_string, body, i)

        var expression = parseExpr(sub.substr(2) & ": nil")
        var bodyIndex  = macros.high(expression)
        expression[bodyIndex] = body

        node.add expression

        # echo i
        # echo "etf: ", value.substr(read + sub_read)# + 6)

        inc(read, 2)
        return true


proc check_expression(value: string, node: PNimrodNode, read: var int) {.compileTime.} =
    ## Check for the opening of an expression, %(), otherwise
    ## if @ident parse as individual identifier
    var sub: string

    if value.skipUntil('(', read) == 0:
        value.parse_to_close(sub, read)
        node.add newCall("add", ident("result"), newCall("$", parseExpr(sub)))

    else:
        # Process as individual variable
        read += value.parseWhile(sub, validChars, start=read)

        if sub != "":
            node.add newCall("add", ident("result"), newCall("$", ident(sub)))


proc transform(info_string: string, result: PNimrodNode, index: var int) =
    # Transform info and add to result statement list
    while index < info_string.len:

        # TODO - Skip string '"'

        var sub: string
        var read = index + info_string.parseUntil(sub, '$', start=index)

        # Check for repeating '$'
        if info_string.substr(read, read + 1) == "$$":
            # Split string
            result.add newCall("add", ident("result"), newStrLitNode(sub & "$"))

            # Increment to next point
            index = read + 1

        else:
            # Add literal string information up-to the `$` symbol
            result.add newCall("add", ident("result"), newStrLitNode(sub))

            # Check if we have reached the end of the string
            if read == info_string.len:
                index = read
                break

            # Check sections, recursively calls
            # transform as needed; dropping cursor
            # back here with updated index & read
            if not info_string.check_section(result, read):
                # Process as individual expression
                info_string.check_expression(result, read)

            # Increment to next point
            index = read


macro tmpl*(body: expr): stmt =
    ## Transform `tmpl` body into nimrod code
    ## Put body into procedure named `name`
    ## which returns type `string`
    result = newStmtList()

    result.add parseExpr("if result == nil: result = \"\"")

    var value = if body.kind in nnkStrLit..nnkTripleStrLit: body
                else: body[1]

    var index = 0
    transform(
        reindent($toStrLit(value)),
        result, index
    )


# Tests
when isMainModule:

    when false:
        # No substitution
        proc no_substitution: string = tmpl html"""
            <h1>Template test!</h1>
        """

        # Single variable substitution
        proc substitution(who = "nobody"): string = tmpl html"""
            <div id="greeting">hello $who!</div>
        """

        # Expression template
        proc test_expression(nums: openarray[int] = []): string =
            var i = 2
            tmpl html"""
                $(no_substitution())
                $(substitution("Billy"))
                <div id="age">Age: $($nums[i] & "!!")</div>
            """

        echo test_expression([26, 27, 28, 29])

    else:
        # Statement template
        proc test_statements(nums: openarray[int] = []): string =
            tmpl html"""
                <ul>${{for i in nums:
                    <li>$(i * 2)</li>
                }}</ul>
            """

        # Run template procedures
        echo test_statements([0, 2, 4, 6])