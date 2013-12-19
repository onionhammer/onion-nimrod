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
# proc parse_through_string*(quote = '"') {.compiletime.}
#     ## Parses until ending " or ' is reached.

# proc parse_thru_eol* {.compiletime.}
#     ## Reads until and past the end of the current line, unless
#     ## a non-whitespace character is encountered first

# proc parse_to_close*(open="(", close=")", opened=0) {.compiletime.}
#     ## Reads until all opened braces are closed
#     ## ignoring any strings "" or ''

# proc parse_if_when_try* {.compiletime.}
#     ## Parses if/when/try /elif /else /except /finally statements

# proc parse_case* {.compiletime.}
#     ## Parses case /of /else statements

# proc parse_simple_statement* {.compiletime.}
#     ## Parses for/while

# proc parse_stmt_list* {.compiletime.}
#     ## Parses unguided ${} block

# proc parse_expression* {.compiletime.}
#     ## Determine what to do once a $ is encountered

proc parse_until_symbol*(node: PNimrodNode, value: string, index: var int): bool {.compiletime.}
proc parse_template*(node: PNimrodNode, value: string) {.compiletime.}


# Procedure Definitions
proc substring(value: string, index: int, length = 0): string {.compiletime.} =
    return if length == 0: value.substr(index)
           else:           value.substr(index, index + length-1)


proc parse_until_symbol(node: PNimrodNode, value: string, index: var int): bool =
    ## Parses a string until a $ symbol is encountered, if
    ## two $$'s are encountered in a row, a split will happen
    ## removing one of the $'s from the resulting output
    var read       = value.skipUntil('$', index)
    var splitValue = value.substring(index, read)

    # Append string up until the `$` symbol
    node.add newCall("add", ident("result"), newStrLitNode(splitValue))
    inc(index, read)

    if index < value.len:
        inc(index)  # We know value[index] == '$', so go ahead one more

        case value[index]
        of '$':
            # Check for duplicate `$`, meaning this is an escaped $
            node.add newCall("add", ident("result"), newStrLitNode(splitValue & "$"))
            inc(index, 1)

        of '(':
            # Check for open `(`, which means parse as simple single-line expression.

        of '{':
            # Check for open `{`, which means open statement list

        else:
            # Otherwise parse while valid `identChars` and make expression w/ $
            var identifier: string
            read = value.parseWhile(identifier, identChars, index)
            node.add newCall("add", ident("result"), newCall("$", ident(identifier)))
            inc(index, read)
            echo value.substring(index)


        # - for/while means open simple statement
        # - if/when/case/try means complex statement

        return true


proc parse_template*(node: PNimrodNode, value: string) =
    ## Parses through entire template, outputing valid
    ## Nimrod code into the input `node` AST.
    var index  = 0
    while index < value.len:
        if parse_until_symbol(node, value, index): nil
        else: break


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
