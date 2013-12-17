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
    let diff        = open.len - 1

    while i < remainder.len-1:
        var c = $remainder.substr(i, i + diff)

        if   c == open:  inc(open_braces)
        elif c == close: dec(open_braces)
        elif c == "\"":  skip_string(remainder, i)
        elif c == "'":   skip_string(remainder, i, '\'')

        if open_braces == 0: break
        else: inc(i)

    line = remainder.substr(0, i - diff)
    inc(read, i)


proc make_statement(expression_string: string, body: PNimrodNode): PNimrodNode {.compileTime.} =
    # Substitute body of expression with derived stmt
    result = parseExpr(expression_string.substr(2) & ": nil")

    if result.kind == nnkIfStmt:
        var elifBranch = result[0]
        var stmtIndex  = macros.high(elifBranch)
        elifBranch[stmtIndex] = body

    else: result.body = body


proc check_section(value: string, node: PNimrodNode, read: var int): bool {.compileTime.} =
    ## Check for opening of a statement section %{{  }}
    #TODO
    # - Handle if/$elif/$else
    # - Handle case/$of/$else
    #######

    inc(read)
    if value.skipWhile({'{'}, read) == 2:
        # Parse value until colon
        var sub: string
        var sub_read = value.parseUntil(sub, ':', start=read)

        # Skip to end of line, if there are no more non-whitespace
        # characters at the end of the ":" expression
        var ws_string: string
        var ws = value.parseUntil(ws_string, 0xA.char, read + sub_read + 1)

        if ws_string.skipWhitespace != ws: ws = 0
        else: inc(ws)

        # Generate body of statement
        inc(read, sub_read + 1 + ws)

        var body_string: string
        value.parse_to_close(body_string, read, open="{{", close="}}", 1)

        # Call transform to transform body of statement
        var i    = 0
        var body = newStmtList()
        transform(body_string, body, i)

        # Append to generated code
        node.add make_statement(sub, body)

        inc(read, 2)
        return true


proc check_expression(value: string, node: PNimrodNode, read: var int) {.compileTime.} =
    ## Check for the opening of an expression, %(), otherwise
    ## if @ident parse as individual identifier
    var sub: string

    if value.skipUntil('(', read) == 0:
        value.parse_to_close(sub, read)
        node.add newCall("add", ident("result"), newCall("$", parseExpr(sub)))
        inc(read)

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


#TODO tmpl open("file") = slurp input file & parse

# Tests
when isMainModule:

    when false:
        ## Working tests

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

        proc test_statements(nums: openarray[int] = []): string =
            tmpl html"""
                $(test_expression(nums))
                ${{if false:
                    <ul>
                    ${{for i in nums:
                        <li>$(i * 2)</li>
                    }}</ul>
                }}
            """

        echo test_statements([26, 27, 28, 29])

    elif false:
        ## Future
        proc test_if_else: string = tmpl html"""
            $if true: {{
                <div>statement is true!</div>
            }}
            $else: {{
                <div>statement is false!</div>
            }}
            <ul>
            $for x in [0,1,2]: {{
                <li>$x</li>
            }}
            </ul>
        """

        proc test_case: string =
            const i = 5
            tmpl html"""
                ${{case i
                    $of 5: ding!
                    $else: nothing
                }}
            """

    else:
        ## In Progress
        proc test_statements(nums: openarray[int] = []): string =

            tmpl html"""
                ${{if 5 * 5 == 25:
                    hello $("do things?")
                }}
                <ul>
                ${{for i in nums:
                    <li>$(i * 2)</li>
                }}</ul>
                """


        # Run template procedures
        echo test_statements([0, 2, 4, 6])