import sequtils, future

iterator numbers(num = 10): int =
    for i in 1.. num:
        yield i

let values = toSeq(numbers())
    .filter(x => x mod 2 == 1)
    .map((x: int) => x + x - 1)

echo values
