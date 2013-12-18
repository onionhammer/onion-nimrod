# Imports
import tables, parseutils, macros
import annotate


# Fields
const validChars = {'a'..'z', 'A'..'Z', '0'..'9', '_'}


# Procedure Declarations
proc parseThroughString*(strType = '"') {.compiletime.}
    ## Parses until ending " or ' is reached.


proc parseToClose*(open="(", close=")", opened=0) {.compiletime.}
    ## Parses a string until all opened braces are closed
    ## ignoring any strings "" or ''


proc parseIfWhen* {.compiletime.}
    ## Parses if/when /elif /else statements


proc parseCase* {.compiletime.}
    ## Parses case /of /else statements


proc parseGeneralStatement* {.compiletime.}
    ## Parses for/while


proc parseExpression* {.compiletime.}
    ## Determine what to do once a $ is encountered


proc parseUntilSymbol* {.compiletime.}
    ## Parses a string until a $ symbol is encountered, if
    ## two $$'s are encountered in a row, a split will happen
    ## removing one of the $'s from the resulting output


# Procedure Definitions


# Tests
when isMainModule:

    const x = 5

    const no_substitution = html"""
        <p>Test!</p>
    """

    const basic = html"""
        <p>Test $$x</p>
        $x
    """

    const expression = html"""
        <p>Test $$(x * 5)</p>
        $(x * 5)
    """

    const forIn = html"""
        <p>Test for</p>
        <ul>
        $for y in [0,1,2]: {{
            <li>$y</li>
        }}
        </ul>
    """

    const ifElifElse = html"""
        <p>Test if/elif/else</p>
        $if x == 8: {{
            <div>x is 8!</div>
        }}
        $elif x == 7: {{
            <div>x is 7!</div>
        }}
        $else: {{
            <div>x is neither!</div>
        }}
    """

    const caseOfElse = html"""
        <p>Test case</p>
        $case x
        of 5: {{
            <div>x == 5</div>
        }}
        of 6: {{
            <div>x == 6</div>
        }}
        else: {{
            <div>x == ?</div>
        }}
    """

    {.fatal:"TASK COMPLETE".}