import tables, parseutils, macros
import annotate

#TODO - Remove me
import os, json, marshal, strutils


# Fields
const validChars = {'a'..'z', 'A'..'Z', '0'..'9'}


# Procedures
proc transform(info_string: string, result: PNimrodNode) {.compileTime.}

proc check_section(value: string, node: PNimrodNode, index, read: var int): bool {.compileTime.} =
    if value.skipWhile({'{'}, index) == 2:
        # Parse value until colon
        var sub: string
        var sub_read = value.parseUntil(sub, ':', start=index)

        # TODO - Replace statement list with parsed remainder

        var expression = parseExpr(sub.substr(2) & ": nil")
        node.add expression

        inc(index, 2)
        return true
    inc(read)


proc check_expression(value: string, node: PNimrodNode, index, read: var int) {.compileTime.} =

    # Check for open parenthesis '('

    # Process as individual variable
    var sub: string
    read += value.parseWhile(sub, validChars, start=read)

    if sub != "":
        node.add newCall("add", ident("result"), newCall("$", ident(sub)))



proc transform(info_string: string, result: PNimrodNode) =
    var transform_string = ""

    result.add parseExpr("result = \"\"")

    # Transform info and add to result statement list
    var index = 0
    while index < info_string.len:
        var sub: string
        var read = index + info_string.parseUntil(sub, '%', start=index)

        # Add literal string information up-to the `%` symbol
        result.add newCall("add", ident("result"), newStrLitNode(sub))

        # Check if we have reached the end of the string
        if info_string.len == read:
            break

        # Check sections, recursively calls
        # transform as needed; dropping cursor
        # back here with updated index & read
        if not info_string.check_section(result, index, read):

            # Process as individual expression
            info_string.check_expression(result, index, read)

        # Increment to next point
        index = read


macro tmpl*(body: expr): stmt =
    ## Transform `tmpl` body into nimrod code
    ## Put body into procedure named `name`
    ## which returns type `string`
    result = newStmtList()

    transform(
        reindent($toStrLit(body[1])),
        result
    )


# Tests
when isMainModule:

    proc sample(nums: openarray[int] = []): string =

        # No substitution
        # tmpl html"""
        #     <div>Test!</div>
        # """

        # Simple example
        var i = 2
        tmpl html"""
            <div id="list">hello "%(nums[i])"</div>
        """

        # Looping example
        # tmpl html"""
        #     <ul id="list">
        #     %{{for i in nums:
        #         <li>%i</li>
        #     }}
        #     </ul>
        # """

    # Template
    echo sample([0, 2, 4, 6])