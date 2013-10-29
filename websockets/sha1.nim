#http://stackoverflow.com/questions/5630546/a-memory-efficient-sha1-implementation
import unsigned, strutils

## Fields
const sha_digest_size = 20

## Types
type
    SHA1Digest = array[0 .. sha_digest_size-1, uint32]
    SHA1Buffer = array[0 .. 80-1, uint32]

## Templates & Procedures
template rol(value, bits: uint32): uint32 {.immediate.} = 
    (value shl bits) or (value shr (32 - bits))

proc clearBuffer(w: var array[0 .. 80-1, uint32]) =
    for i in 0 .. 15:
        w[i] = 0

proc `$`*(digest: SHA1Digest): string = 
    const digits = "0123456789abcdef"

    var arr: array[0 .. sha_digest_size*2, char]

    for i in 0 .. int(sha_digest_size/4 - 1):
        let c = digest[i]

        for j in countdown(8-1, 0):
            arr[i*8+j] = digits[(c shr uint32(28 - j * 4)) and 0xf]

    return $arr

proc innerHash(result, w: var openarray[uint32]) =
    var
        a = result[0]
        b = result[1]
        c = result[2]
        d = result[3]
        e = result[4]

    var round = 0

    template sha1(func, val: expr): stmt =
        let t = rol(a, 5) + func + e + uint32(val) + w[round]
        e = d
        d = c
        c = rol(b, 30)
        b = a
        a = t

    template process(body: stmt): stmt =
        w[round] = rol(w[round - 3] xor w[round - 8] xor w[round - 14] xor w[round - 16], 1)
        body
        inc(round)

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

    result[0] += a
    result[1] += b
    result[2] += c
    result[3] += d
    result[4] += e

proc compute*(src: string): array[0 .. sha_digest_size-1,uint32] =
    #Initialize result
    result[0] = uint32(0x67452301)
    result[1] = uint32(0xefcdab89)
    result[2] = uint32(0x98badcfe)
    result[3] = uint32(0x10325476)
    result[4] = uint32(0xc3d2e1f0)

    #Create w buffer
    var w: array[0 .. 80-1, uint32]

    let byteLen  = src.len
    let endBlock = byteLen - 64

    var endCurrentBlock = 0
    var currentBlock    = 0

    while currentBlock <= endBlock:
        endCurrentBlock = currentBlock + 64

        for i in countup(0, endCurrentBlock-1, 4):
            w[i] = uint32(src[currentBlock+3]) or
                   uint32(src[currentBlock+2]) shl 8 or
                   uint32(src[currentBlock+1]) shl 16 or
                   uint32(src[currentBlock])   shl 24

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

    var result: string

    #test sha1 - 60 char input
    result = ($compute("JhWAN0ZTmRS2maaZmDfLyQ==258EAFA5-E914-47DA-95CA-C5AB0DC85B11")).toLower()
    assert(result == "e3571af6b12bcb49c87012a5bb5fdd2bada788a4", "SHA1 result did not match")
    echo result

    #test sha1 - longer input
    #result = ($compute("abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz")).toLower()
    #assert(result == "f2090afe4177d6f288072a474804327d0f481ada", "SHA1 result did not match")

    #test sha1 - shorter input
    #result = ($compute("shorter")).toLower()
    #assert(result == "c966b463b67c6424fefebcfcd475817e379065c7", "SHA1 result did not match")