# Ref: http://nimrod-lang.org/macros.html
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
proc parse_through_string*(quote = '"') {.compiletime.}
    ## Parses until ending " or ' is reached.


proc parse_thru_eol* {.compiletime.}
    ## Reads until and past the end of the current line, unless
    ## a non-whitespace character is encountered first


proc parse_to_close*(open="(", close=")", opened=0) {.compiletime.}
    ## Reads until all opened braces are closed
    ## ignoring any strings "" or ''


proc parse_if_when_try* {.compiletime.}
    ## Parses if/when/try /elif /else /except /finally statements


proc parse_case* {.compiletime.}
    ## Parses case /of /else statements


proc parse_simple_statement* {.compiletime.}
    ## Parses for/while

proc parse_stmt_list* {.compiletime.}
    ## Parses unguided ${} block


proc parse_expression* {.compiletime.}
    ## Determine what to do once a $ is encountered


proc parse_until_symbol* {.compiletime.}
    ## Parses a string until a $ symbol is encountered, if
    ## two $$'s are encountered in a row, a split will happen
    ## removing one of the $'s from the resulting output


proc parse_template*(node: PNimrodNode, value: string) {.compiletime.}
    ## Parses through entire template, outputing valid
    ## Nimrod code into the input `node` AST.


# Procedure Definitions
proc substring(value: string, index: int, length = 0): string {.compiletime.} =
    return if length == 0: value.substr(index)
           else:           value.substr(index, index + length-1)


proc parse_template*(node: PNimrodNode, value: string) =
    echo value


macro tmpl(body: expr): stmt =
    result = newStmtList()

    var value = if body.kind in nnkStrLit..nnkTripleStrLit: body
                else: body[1]

    parse_template(result, reindent($toStrLit(value)))


# Run tests
when isMainModule:
    include tests

    when not defined(release):
        static:
            quit("TASK COMPLETE")
