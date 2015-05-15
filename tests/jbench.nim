import json, times, strutils

# Run
# ./jbench;python jbench.py

let jsonData = json.parseFile("data.json")
var result = ""

proc escape(value: string): string =
    const charsToEscape = { '"', '\\', '/', '\b', '\f', '\l', '\r', '\t' }
    result = newStringOfCap(value.len)

    for c in value:
        if c in charsToEscape:
            case c:
            of '\b': result.add "\\b"
            of '\f': result.add "\\f"
            of '\l': result.add "\\n"
            of '\r': result.add "\\r"
            of '\t': result.add "\\t"
            else:    result.add '\\'; result.add c
        else:
            result.add c

proc render(result: var string, node: JsonNode) =
    var comma = false

    case node.kind:
    of JArray:
        result.add "["
        for child in node:
            if comma: result.add ","
            else: comma = true
            result.render(child)
        result.add "]"
    of JObject:
        result.add "{"
        for key, value in items(node.fields):
            if comma: result.add ","
            else: comma = true
            result.add "\""
            result.add key.escape()
            result.add "\":"
            result.render(value)
        result.add "}"
    of JString:
        result.add "\""
        result.add node.str.escape
        result.add "\""
    of JInt:
        result.add($node.num)
    of JFloat:
        result.add($node.fnum)
    of JBool:
        result.add($node.bval)
    of JNull:
        result.add "null"

proc render(node: JsonNode): string =
    result = newStringOfCap(node.len * 10)
    result.render(node)

when isMainModule:

    template bench(name: expr, op: stmt) =
        echo name
        let start = cpuTime()
        for i in 0.. 1000:
            op
        echo "  time: ", cpuTime() - start, " s"

    bench "Current Standard Library":
        result = $jsonData

    bench "Modified Standard Library":
        result = render(jsonData)

when false:
    echo "test \bone".escape()