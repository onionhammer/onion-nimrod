## subscribers.nim
##
## Basic event callback library
##
## .. code-block:: Nim
##   # Initializes an event publisher
##   var onCallback = Event[string]()
##
##   # Adds a subscriber
##   onCallback += proc(msg: string) =
##      echo msg
##
##   # Invokes all subscribers
##   onCallback("hello events!")
##
##   # Reset event, removing all subscribers
##   onCallback.reset()

type
    EventArgs* = object of RootObj
        ## Empty Event Args
    Event*[T] = object
        ## Event publisher
        subs: seq[proc(e: T)]

# Fields
let Empty* = EventArgs()

# Procedures
proc `()`*(pub: Event[EventArgs], e = Empty) =
    ## Publish to all event handler callbacks
    if pub.subs != nil:
        for sub in pub.subs:
            sub(e)

proc `()`*[T](pub: Event, e: T) =
    ## Publish to all event handler callbacks
    if pub.subs != nil:
        for sub in pub.subs:
            sub(e)

proc reset*(pub: var Event) =
    ## Reset all events
    if pub.subs != nil:
        pub.subs.setLen(0)

proc add*[T](pub: var Event, sub: proc(e: T)) =
    ## Add an event subscription
    if pub.subs == nil: pub.subs = @[ sub ]
    else: pub.subs.add(sub)

proc del*[T](pub: var Event, sub: proc(e: T)) =
    ## Remove an event subscription
    let i = pub.subs.find(sub)
    if i >= 0:
        pub.subs.del(i)

template `+=`*[T](pub: var Event, sub: proc(e: T)) =
    ## Add an event subscription
    add(pub, sub)

template `-=`*[T](pub: var Event, sub: proc(e: T)) =
    ## Remove an event subscription
    del(pub, sub)

# Tests
when isMainModule:
    var pass    = false
    var onEvent = Event[EventArgs]()

    onEvent += proc(e: EventArgs) = pass = true
    onEvent()
    assert pass
    onEvent.reset()

    var i = 0
    proc incrementI(e: EventArgs) = inc(i)
    onEvent += incrementI
    onEvent += incrementI
    onEvent -= incrementI
    onEvent += incrementI

    onEvent()
    assert i == 2

    onEvent()
    assert i == 4

    onEvent.reset()
    onEvent()
    assert i == 4

    var x = 0
    proc add(e: int) = x += e

    var onAdd = Event[int]()
    onAdd += add
    onAdd(1)
    onAdd(2)
    onAdd(3)
    assert x == 6
