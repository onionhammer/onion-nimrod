import tables, parseutils, macros
import annotate

#TODO - Remove me
import os, json, marshal, strutils


# Fields
const validChars = {'a'..'z', 'A'..'Z', '0'..'9'}


# Procedures
proc transform(info_string: string, result: PNimrodNode) {.compileTime.}


proc parse_to_close(value: string, line: var string, read: var int, open='(', close=')') {.compileTime.} =
    ## Parse a value until all opened braces are closed, excluding strings ("" and '')
    var remainder = value.substr(read)
    var i = 0
    var r = 0

    var open_braces = 0
    while i < remainder.len-1:
        var c = remainder[i]

        if   c == open:  inc(open_braces)
        elif c == close: dec(open_braces)
        elif c == '"':
            # Go ahead to next character & find end of string
            inc(i);
            while i < remainder.len-1:
                inc(i, remainder.skipUntil({'\\', '"'}, i))
                break

        if open_braces == 0: break
        else: inc(i)

    line = remainder.substr(0, i)
    inc(read, i+1)


proc check_section(value: string, node: PNimrodNode, read: var int): bool {.compileTime.} =
    ## Check for opening of a statement section %{{  }}
    if value.skipWhile({'{'}, read) == 2:
        # Parse value until colon
        var sub: string
        var sub_read = value.parseUntil(sub, ':', start=read)

        # TODO - Replace statement list with parsed remainder

        var expression = parseExpr(sub.substr(2) & ": nil")
        node.add expression

        inc(read, 2)
        return true

    else:
        inc(read)


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


proc transform(info_string: string, result: PNimrodNode) =
    # Transform info and add to result statement list
    var index = 0
    while index < info_string.len:
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
            if info_string.len == read:
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

    transform(
        reindent($toStrLit(value)),
        result
    )


# Tests
when isMainModule:

    # No substitution
    proc no_substitution: string = tmpl html"""
        <div>Test!</div>
    """

    # Single variable substitution
    proc substitution(who = "nobody"): string = tmpl html"""
        <div id="greeting">hello $who!</div>
    """

    # Expression template
    proc test_expression(nums: openarray[int] = []): string =
        var i = 2
        tmpl html"""
            <div id="greeting">hello $($nums[i] & "!!")</div>
        """

    # Statement template
    proc test_statements(nums: openarray[int] = []): string = ""
        # tmpl html"""
        #     <ul>${{for i in nums:
        #         <li>$i</li>
        #     }}</ul>
        # """

    # Run template procedures
    echo no_substitution()

    echo substitution("world")

    echo test_expression([0, 2, 4, 6])

    echo test_statements([0, 2, 4, 6])