#http://stackoverflow.com/questions/5630546/a-memory-efficient-sha1-implementation
import unsigned, strutils

const sha_digest_size = 20

template rol(value, bits: uint32): uint32 {.immediate.} = 
    (value shl bits) or (value shr (32 - bits))

proc digitToHex(digest: openarray[uint32]): string =
    result = ""

    for i in 0 .. int(sha_digest_size/4) - 1:
        let value = digest[i]
        result.add(ord(value).toHex(8).toLower())

proc innerHash(result: var array[0 .. sha_digest_size-1,uint32], w: var array[0..80-1, uint32]) =
    var
        a = result[0]
        b = result[1]
        c = result[2]
        d = result[3]
        e = result[4]

    var round = 0

    template sha1(func: expr, val: uint32): stmt =
        let t = rol(a, 5) + func + e + val + w[round]
        e = d
        d = c
        c = rol(b, 30)
        b = a
        a = t

    while round < 16:
        sha1((b and c) or (not b and d), 0x5a827999)
        inc(round)

    while round < 20:
        w[round] = rol(w[round - 3] xor w[round - 8] xor w[round - 14] xor w[round - 16], 1)
        sha1((b and c) or (not b and d), 0x5a827999)
        inc(round)

    while round < 40:
        w[round] = rol(w[round - 3] xor w[round - 8] xor w[round - 14] xor w[round - 16], 1)
        sha1(b xor c xor d, 0x6ed9eba1)
        inc(round)

    while round < 60:
        w[round] = rol(w[round - 3] xor w[round - 8] xor w[round - 14] xor w[round - 16], 1);
        sha1((b and c) or (b and d) or (c and d), uint32(0x8f1bbcdc))
        inc(round)

    while round < 80:
        w[round] = rol((w[round - 3] xor w[round - 8] xor w[round - 14] xor w[round - 16]), 1);
        sha1(b xor c xor d, uint32(0xca62c1d6))
        inc(round)

    result[0] += a
    result[1] += b
    result[2] += c
    result[3] += d
    result[4] += e

proc clearBuffer(w: var array[0..80-1, uint32]) =
    for i in 0..15:
        w[i] = 0

proc calc(src: string): array[0 .. sha_digest_size-1,uint32] =
    #init result
    result[0] = uint32(0x67452301)
    result[1] = uint32(0xefcdab89)
    result[2] = uint32(0x98badcfe)
    result[3] = uint32(0x10325476)
    result[4] = uint32(0xc3d2e1f0)

    #round buffer
    var w: array[0..80-1, uint32]
    let byteLen = src.len

    let endBlock = byteLen - 64
    var endCurrentBlock = 0
    var currentBlock = 0

    while currentBlock <= endBlock:
        endCurrentBlock = currentBlock + 64

        for i in countup(0, endCurrentBlock-1, 4):
            w[i] = uint32(src[currentBlock+3]) or
                (uint32(src[currentBlock+2]) shl 8) or
                (uint32(src[currentBlock+1]) shl 16) or
                (uint32(src[currentBlock]) shl 24)

        innerHash(result, w)

    #Handle last and not full 64 byte block if existing
    endCurrentBlock = byteLen - currentBlock

    clearBuffer(w)

    var lastBlockBytes = 0
    while lastBlockBytes < endCurrentBlock:
        let value = w[lastBlockBytes shr 2] or (
            uint32(src[lastBlockBytes + currentBlock]) shl 
            uint32((3 - (lastBlockBytes and 3)) shl 3)
        )

        w[lastBlockBytes shr 2] = value
        inc(lastBlockBytes)

    w[lastBlockBytes shr 2] = w[lastBlockBytes shr 2] or (
        uint32(0x80) shl uint32((3 - (lastBlockBytes and 3)) shl 3)
    )

    if endCurrentBlock >= 56:
        innerHash(result, w)
        clearBuffer(w)

    w[15] = uint32(byteLen shl 3)
    innerHash(result, w)

when isMainModule:
    
    let data       = "JhWAN0ZTmRS2maaZmDfLyQ==258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    let sha1Result = "e3571af6b12bcb49c87012a5bb5fdd2bada788a4"

    #test sha
    var result = calc(data)

    echo "assert ", result.digitToHex(), "is valid"
    assert(result.digitToHex() == sha1Result, "SHA1 result did not match")
    echo "pass"
