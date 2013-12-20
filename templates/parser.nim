# Ref:
# http://nimrod-lang.org/macros.html
# http://nimrod-lang.org/parseutils.html
#
discard """
Template Parser Logic
- $ means 'parse_expression'
    - ( means parse as simple single-line expression.
    - { means open statement list
    - for/while means open simple statement
    - if/when/case/try means complex statement
    - Otherwise parse while valid identChars and make expression w/ $
- When statement block is opened {, skip EOL after
- When statement block is closed }, skip EOL after
- Call reindent on statement substrings, to the level of indentation
  as the opening of the first line w/ the $
"""

# Imports
import tables, parseutils, macros
import annotate


# Fields
const identChars = {'a'..'z', 'A'..'Z', '0'..'9', '_'}


# Procedure Declarations
proc parse_until_symbol*(node: PNimrodNode, value: string, index: var int): bool {.compiletime.}
proc parse_template*(node: PNimrodNode, value: string) {.compiletime.}

# proc parse_through_string*(quote = '"') {.compiletime.}
#     ## Parses until ending " or ' is reached.

# proc parse_if_when_try* {.compiletime.}
#     ## Parses if/when/try /elif /else /except /finally statements

# proc parse_case* {.compiletime.}
#     ## Parses case /of /else statements

# proc parse_stmt_list* {.compiletime.}
#     ## Parses unguided ${} block

# proc parse_expression* {.compiletime.}
#     ## Determine what to do once a $ is encountered


# Procedure Definitions
proc substring(value: string, index: int, length = 0): string =
    return if length == 0: value.substr(index)
           else:           value.substr(index, index + length-1)


proc parse_thru_eol(value: string, index: int): int =
    ## Reads until and past the end of the current line, unless
    ## a non-whitespace character is encountered first
    var remainder: string
    var read = value.parseUntil(remainder, {0x0A.char}, index)
    if remainder.skipWhitespace() == read:
        return read + 1


proc trim_eol(value: var string) =
    ## Removes everything after the last line if it contains nothing but whitespace
    var ending = value.len - 1
    for i in countdown(ending, 0):
        # If \n, trim and return
        if value[i] == 0x0A.char:
            value = value.substr(0, i)
            break

        # This is the first character
        if i == 0:
            value = ""
            break

        # Skip change
        if not (value[i] in [' ', '\t']): break


proc parse_through_string(value: string, i: var int, strType = '"') =
    ## Parses until ending " or ' is reached.
    inc(i)
    if i < value.len-1:
        inc(i, value.skipUntil({'\\', strType}, i))


proc parse_to_close*(value: string, index: int, open='(', close=')', opened=0): int =
    ## Reads until all opened braces are closed
    ## ignoring any strings "" or ''
    var remainder   = value.substring(index)
    var open_braces = opened
    result = 0

    while result < remainder.len:
        var c = remainder[result]

        if   c == open:  inc(open_braces)
        elif c == close: dec(open_braces)
        elif c == '"':   remainder.parse_through_string(result)
        elif c == '\'':  remainder.parse_through_string(result, '\'')

        if open_braces == 0: break
        else: inc(result)


proc parse_simple_statement(node: PNimrodNode, value: string, index: var int) {.compiletime.} =
    ## Parses for/while

    # Parse until an open brace `{`
    var splitValue: string
    var read       = value.parseUntil(splitValue, '{', index)
    var expression = parseExpr(splitValue & ":nil")
    inc(index, read + 1)

    # Parse through EOL
    inc(index, value.parse_thru_eol(index))

    # Parse through { .. }
    read = value.parse_to_close(index, open='{', close='}', opened=1)

    # Add parsed sub-expression into body
    var body = newStmtList()
    parse_template(body, value.substring(index, read))
    inc(index, read + 1)

    var stmtIndex = macros.high(expression)
    expression[stmtIndex] = body

    node.add(expression)

    # Parse through EOL again
    inc(index, value.parse_thru_eol(index))


proc parse_until_symbol(node: PNimrodNode, value: string, index: var int): bool =
    ## Parses a string until a $ symbol is encountered, if
    ## two $$'s are encountered in a row, a split will happen
    ## removing one of the $'s from the resulting output
    var splitValue: string
    var read = value.parseUntil(splitValue, '$', index)
    var insertionPoint = node.len

    inc(index, read + 1)
    if index < value.len:

        case value[index]
        of '$':
            # Check for duplicate `$`, meaning this is an escaped $
            node.add newCall("add", ident("result"), newStrLitNode("$"))
            inc(index, 1)

        of '(':
            # Check for open `(`, which means parse as simple single-line expression.
            read = value.parse_to_close(index, opened=1) - 2
            node.add newCall("add", ident("result"), parseExpr("$" & value.substring(index, read)))
            inc(index, read)

        of '{':
            # Check for open `{`, which means open statement list
            trim_eol(splitValue)

            read = value.parse_to_close(index, open='{', close='}')
            node.add parseStmt(
                value.substring(index + 1, read - 1)
            )
            inc(index, read + 1)

            #Parse thru EOL
            inc(index, value.parse_thru_eol(index))

        else:
            # Otherwise parse while valid `identChars` and make expression w/ $
            var identifier: string
            read = value.parseWhile(identifier, identChars, index)

            if identifier in ["for", "while"]:
                ## for/while means open simple statement
                parse_simple_statement(node, value, index)

            elif identifier in ["if", "when", "case", "try"]:
                ## if/when/case/try means complex statement
                echo "TODO - Parse complex statement"
                inc(index, read)

            elif identifier.len > 0:
                ## Treat as simple variable
                node.add newCall("add", ident("result"), newCall("$", ident(identifier)))
                inc(index, read)

        result = true

    # Insert
    if splitValue.len > 0:
        node.insert insertionPoint, newCall("add", ident("result"), newStrLitNode(splitValue))


proc parse_template*(node: PNimrodNode, value: string) =
    ## Parses through entire template, outputing valid
    ## Nimrod code into the input `node` AST.
    var index = 0
    while index < value.len and
          parse_until_symbol(node, value, index): nil


macro tmpl(body: expr): stmt =
    result = newStmtList()

    result.add parseExpr("if result == nil: result = \"\"")

    var value = if body.kind in nnkStrLit..nnkTripleStrLit: body
                else: body[1]

    parse_template(result, reindent($toStrLit(value)))


# Run tests
when isMainModule:
    include tests

    const release = true

    when not release:
        static:
            quit("TASK COMPLETE")
