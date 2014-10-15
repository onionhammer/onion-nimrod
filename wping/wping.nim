## wping
## =====
## Periodically gets input http {address} and searches for {search} string.
##
## Command Line:
## - wping {address} {search}
##
## TODO:
## - Add {startime} option

# Imports
import os, osproc, future, httpclient, strutils, parseopt2

# Fields
const numPings  = 5
const pingDelay = 250
var sleepTime*  = 20000 # in Milliseconds

# Types
type WPing* = object
    address*: string
    search*: string

# Procedures
proc normalize(value: string): string =
    ## Normalize the input string, removing any spaces or periods
    value.replace(" ").replace(".").toLower

proc checkMatch(ping: WPing, content: string): bool =
    ## Checks if the content contains the ping search
    content.normalize.find(
        ping.search.normalize
    ) >= 0

proc signal*(ping: WPing): WPing {.discardable.} =
    ## Signal the user that a match was found.
    result = ping
    echo "Found: ", ping.search
    for i in 0.. < numPings:
        stdout.write char(0x7)
        echo "found!"
        sleep(pingDelay)

proc open*(ping: WPing): WPing {.discardable.} =
    ## Opens the searched `ping` address
    result = ping
    when defined(windows):
        discard execProcess("explorer " & ping.address)
    else:
        discard execProcess("open " & ping.address)

proc wait*(ping: WPing) : WPing {.discardable.} =
    ## Periodically pings the input address, testing if there
    ## is a match for the input search pattern
    result = ping
    echo "Checking ", ping.address
    while true:
        let content = httpclient.getContent(ping.address)

        try:
            if ping.checkMatch(content):
                return
        except: discard

        sleep(sleepTime)
        continue

when isMainModule:
    proc main =
        ## Default behavior for wping is to parse the
        ## command line and search
        var address, search: string

        for kind, key, value in getopt():
            if address == nil:
                address = key
            else:
                search = key

        if address == nil or search == nil:
            echo "Address or Search parameter was empty"
            return
        elif not address.contains("://"):
            address = "http://" & address

        let ping = WPing(
            address: address,
            search:  search
        )

        ping.wait().open().signal()

    main()