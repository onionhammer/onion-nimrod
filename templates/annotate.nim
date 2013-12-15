import macros, parseutils

# Generate tags
macro make(names: openarray[expr]): stmt {.immediate.} =
    result = newStmtList()

    for i in 0 .. names.len-1:
        result.add newProc(
            name   = ident($names[i]).postfix("*"),
            params = [
                ident("string"),
                newIdentDefs(
                    ident("content"),
                    ident("string")
                )
            ],
            body = newStmtList(
                parseStmt("reindent(content)")
            )
        )


proc reindent*(value: string): string {.noinit.} =
    #Detect indentation
    let length = value.len
    let indent = skipWhitespace(value)

    if indent == 0:
        return value

    #Remove indent amount from `value`
    var newValue = newString(0)
    var index    = indent

    while index < length:
        var line: string
        var lineLen = value.parseUntil(line, 13.char, index)

        #Trim
        if indent + index + lineLen > length:
            newValue.add(line)
        else:
            newValue.add(line & "\n")

        index = index + lineLen + 2 + indent

    return newValue


#Define tags
make([ html, xml, glsl, js, css ])


when isMainModule:
    ## Test tags

    const script = js"""
        var x = 5;
        console.log(x.toString());
    """
    echo script


    const styles = css"""
        .someRule {
            width: 500px;
        }
    """
    echo styles


    const body = html"""
        <ul>
            <li>1</li>
            <li>2</li>
            <li>
                <a hef="#google">google</a>
            </li>
        </ul>
    """
    echo body


    const info = xml"""
        <item>
            <i>1</i>
            <i>2</i>
        </item>
    """
    echo info

    const shader = glsl"""
        void main()
        {
            gl_Position = gl_ProjectionMatrix
                        * gl_ModelViewMatrix
                        * gl_Vertex;
        }
    """
    echo shader