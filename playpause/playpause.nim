import asyncdispatch, httpclient

proc getSite: PFuture[string] {.async.} =
    stdout.write "Enter URL: "

    let client   = newAsyncHttpClient()
    let response = await client.get(stdin.readline)
    return response.body

when isMainModule:

    proc main =
        var task = getSite();
        waitfor task
        echo task.read

    main()