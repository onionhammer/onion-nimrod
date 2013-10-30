#Copyright (c) 2011, Micael Hildenborg
#All rights reserved.

#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions are met:
#* Redistributions of source code must retain the above copyright
#  notice, this list of conditions and the following disclaimer.
#* Redistributions in binary form must reproduce the above copyright
#  notice, this list of conditions and the following disclaimer in the
#  documentation and/or other materials provided with the distribution.
#* Neither the name of Micael Hildenborg nor the
#  names of its contributors may be used to endorse or promote products
#  derived from this software without specific prior written permission.

#THIS SOFTWARE IS PROVIDED BY Micael Hildenborg ''AS IS'' AND ANY
#EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#DISCLAIMED. IN NO EVENT SHALL Micael Hildenborg BE LIABLE FOR ANY
#DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#http://stackoverflow.com/questions/5630546/a-memory-efficient-sha1-implementation
import unsigned, strutils


## Fields
const sha_digest_size = 20


## Types
type
    SHA1State = array[0 .. 5-1, uint32]
    SHA1Buffer = array[0 .. 80-1, uint32]
    SHA1Digest* = array[0 .. sha_digest_size-1, uint8]
    SHA1Context* {.final.} = object
        buffer*: seq[char]


## Templates & Procedures
proc clearBuffer[T](w: var openarray[T], len = 16) =
    for i in 0 .. len-1:
        w[i] = T(0)


proc `$`*(digest: SHA1Digest): string = 
    const digits = "0123456789abcdef"

    var arr: array[0 .. sha_digest_size*2, char]

    for hashByte in countdown(20-1, 0):
        arr[hashByte shl 1] = digits[(digest[hashByte] shr 4) and 0xf]
        arr[(hashByte shl 1) + 1] = digits[(digest[hashByte]) and 0xf]

    return $arr


proc init(result: var SHA1State) =
    result[0] = uint32(0x67452301)
    result[1] = uint32(0xefcdab89)
    result[2] = uint32(0x98badcfe)
    result[3] = uint32(0x10325476)
    result[4] = uint32(0xc3d2e1f0)


proc innerHash(state: var SHA1State, w: var SHA1Buffer) =
    var
        a = state[0]
        b = state[1]
        c = state[2]
        d = state[3]
        e = state[4]

    var round = 0

    template rot(value, bits: uint32): uint32 {.immediate.} = 
        (value shl bits) or (value shr (32 - bits))

    template sha1(func, val: expr): stmt =
        let t = rot(a, 5) + func + e + uint32(val) + w[round]
        e = d
        d = c
        c = rot(b, 30)
        b = a
        a = t

    template process(body: stmt): stmt =
        w[round] = rot(w[round - 3] xor w[round - 8] xor w[round - 14] xor w[round - 16], 1)
        body
        inc(round)

    template wrap(dest, value: expr): stmt {.immediate.} =
        let v = dest + value
        dest = v

    while round < 16:
        sha1((b and c) or (not b and d), 0x5a827999)
        inc(round)

    while round < 20:
        process:
            sha1((b and c) or (not b and d), 0x5a827999)

    while round < 40:
        process:
            sha1(b xor c xor d, 0x6ed9eba1)

    while round < 60:
        process:
            sha1((b and c) or (b and d) or (c and d), 0x8f1bbcdc)

    while round < 80:
        process:
            sha1(b xor c xor d, 0xca62c1d6)

    wrap state[0], a
    wrap state[1], b
    wrap state[2], c
    wrap state[3], d
    wrap state[4], e


proc compute*(src: SHA1Context, byteLen: int, state: var SHA1State): SHA1Digest =

    #Initialize state
    init(state)

    #Create w buffer
    var w: SHA1Buffer

    #Loop through all complete 64byte blocks.
    let endOfFullBlocks = byteLen - 64
    var endCurrentBlock = 0
    var currentBlock    = 0

    while currentBlock <= endOfFullBlocks:
        endCurrentBlock = currentBlock + 64

        var i = 0
        while currentBlock < endCurrentBlock:
            w[i] = uint32(src.buffer[currentBlock+3]) or
                   uint32(src.buffer[currentBlock+2]) shl 8 or
                   uint32(src.buffer[currentBlock+1]) shl 16 or
                   uint32(src.buffer[currentBlock])   shl 24
            currentBlock += 4
            inc(i)

        innerHash(state, w)

    #Handle last and not full 64 byte block if existing
    endCurrentBlock = byteLen - currentBlock
    clearBuffer(w)
    var lastBlockBytes = 0

    while lastBlockBytes < endCurrentBlock:

        var value = uint32(src.buffer[lastBlockBytes + currentBlock]) shl
                    uint32((3 - (lastBlockBytes and 3)) shl 3)

        w[lastBlockBytes shr 2] = w[lastBlockBytes shr 2] or value
        inc(lastBlockBytes)

    w[lastBlockBytes shr 2] = w[lastBlockBytes shr 2] or (
        uint32(0x80) shl uint32((3 - (lastBlockBytes and 3)) shl 3)
    )

    if endCurrentBlock >= 56:
        innerHash(state, w)
        clearBuffer(w)

    w[15] = uint32(byteLen shl 3)
    innerHash(state, w)

    # Store hash in result pointer, and make sure we get in in the correct order on both endian models.
    for i in 0 .. sha_digest_size-1:
        result[i] = uint8((int(state[i shr 2]) shr ((3-(i and 3)) * 8)) and 255)


proc compute*(src: string): SHA1Digest =
    var context: SHA1Context
    var state: SHA1State
    newSeq(context.buffer, src.len)

    for i in 0 .. src.len-1:
        context.buffer[i] = src[i]

    return compute(context, src.len, state)


when isMainModule:

    var result: string

    #test sha1 - 60 char input
    result = ($compute("JhWAN0ZTmRS2maaZmDfLyQ==258EAFA5-E914-47DA-95CA-C5AB0DC85B11")).toLower()
    echo result
    assert(result == "e3571af6b12bcb49c87012a5bb5fdd2bada788a4", "SHA1 result did not match")

    #test sha1 - longer input
    result = ($compute("abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz")).toLower()
    echo result
    assert(result == "f2090afe4177d6f288072a474804327d0f481ada", "SHA1 result did not match")

    #test sha1 - shorter input
    result = ($compute("shorter")).toLower()
    echo result
    assert(result == "c966b463b67c6424fefebcfcd475817e379065c7", "SHA1 result did not match")