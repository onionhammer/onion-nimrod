#http://stackoverflow.com/questions/5630546/a-memory-efficient-sha1-implementation
import unsigned, strutils

const sha_digest_size = 20


template leftrotate(value, bits: uint32): uint32 {.immediate.} = 
    (value shl bits) or (value shr (32 - (bits)))


iterator chunks(message: string): array[0..16-1, char] =
    for i in countup(0, message.len, 16):
        var result: array[0..16-1, char]

        for j in 0 .. result.len-1:
            result[j] = message[i]

        yield result


proc digetToHex(digest: array[0..sha_digest_size-1, uint32]): string =
    result = ""

    for i in countup(0, sha_digest_size, 4):
        for j in 0..4:
            result.add($digest[i*4+j])


proc processBlock (message: string) : array[0..sha_digest_size-1, uint32] =

    var
        h0 = uint32(0x67452301)
        h1 = uint32(0xEFCDAB89)
        h2 = uint32(0x98BADCFE)
        h3 = uint32(0x10325476)
        h4 = uint32(0xC3D2E1F0)

    #Pre-processing:
    #append the bit '1' to the message
    #append 0 <= k < 512 bits '0', so that the resulting message length (in bits)
    #   is congruent to 448 (mod 512)
    #append length of message (before pre-processing), in bits, as 64-bit big-endian integer

    #Process the message in successive 512-bit chunks:
    #break message into 512-bit chunks

    for chunk in message.chunks:
        #break chunk into sixteen 32-bit big-endian words w[i], 0 <= i <= 15
        var w: array[0..16 - 1, uint32]

        echo chunk.len

        #Extend the sixteen 32-bit words into eighty 32-bit words:
        for i in 0..15:
            echo i*4, " ", i*4+1, " ", i*4+2, " ", i*4+3
            w[i] = (w[i*4] shl 24) xor (w[i*4 + 1] shl 16) xor (w[i*4 + 2] shl 8) xor (w[i*4 + 3])

        #for i in 16 .. 79:
        #    w[i] = leftrotate(w[i-3] xor w[i-8] xor w[i-14] xor w[i-16], 1)

        #Initialize hash value for this chunk:
        var
            a = h0
            b = h1
            c = h2
            d = h3
            e = h4

        #Main loop:[37]
        for i in 0 .. 79:
            var k: uint32
            var f: uint32

            if 0 <= i and i <= 19:
                f = (b and c) or ((not b) and d)
                k = uint32(0x5A827999)
            elif 20 <= i and i <= 39:
                f = b xor c xor d
                k = uint32(0x6ED9EBA1)
            elif 40 <= i and i <= 59:
                f = (b and c) or (b and d) or (c and d) 
                k = uint32(0x8F1BBCDC)
            elif 60 <= i and i <= 79:
                f = b xor c xor d
                k = uint32(0xCA62C1D6)

            var temp = leftrotate(a, 5) + f + e + k + w[i]
            e = d
            d = c
            c = leftrotate(b, 30)
            b = a
            a = temp

        #Add this chunk's hash to result so far:
        h0 += a
        h1 += b 
        h2 += c
        h3 += d
        h4 += e

    #Produce the final hash value (big-endian):
    result[0] = h0
    result[1] = h1
    result[2] = h2
    result[3] = h3
    result[4] = h4

when isMainModule:
    
    var data = "JhWAN0ZTmRS2maaZmDfLyQ==258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    var result = processBlock(data)

    echo result.digetToHex()