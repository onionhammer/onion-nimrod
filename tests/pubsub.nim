type Pub*[T] = object
    subs: seq[proc(e: T)]

proc init*[T](pub: var Pub[T]) =
    if pub.subs == nil:
        pub.subs = @[]

proc `()`*[T](pub: Pub, e: T) =
    if pub.subs != nil:
        for sub in pub.subs:
            sub(e)

proc add*[T](pub: var Pub, sub: proc(e: T)) =
    if pub.subs == nil: pub.subs = @[ sub ]
    else: pub.subs.add(sub)

when isMainModule:
    import future

    type Actor = object
        name: string
        onSpeak: Pub[string]

    proc speak(self: var Actor, words: string) =
        self.onSpeak(words)

    proc outputSpeech(e: string) =
        echo e

    var a = Actor()
    a.onSpeak.add do (s: string): echo s
    a.onSpeak.add outputSpeech

    a.speak "Hello world!"

