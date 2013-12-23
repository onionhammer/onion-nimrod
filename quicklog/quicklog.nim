# Imports
import os, marshal


# Types
type TLog* = ref object
  num_lines*: int
  path: string
  file: TFile
  bufSize: int
  mode: TFileMode


# Fields
const BUF_SIZE = -1


# Procedures
template reset_write(log: expr): stmt {.immediate.} =
  if not log.file.endOfFile:
    log.file.setFilePos(log.file.getFileSize - 1)


template reset_read(log: expr): stmt {.immediate.} =
  if log.file.endOfFile:
    log.file.setFilePos(0)


proc open*(path: string, inMode: TFileMode = fmReadWriteExisting, bufSize = BUF_SIZE): TLog =
  new(result)
  var mode = inMode

  if not os.existsFile(path):
    mode = fmReadWrite

  result.path    = path
  result.bufSize = bufSize
  result.mode    = mode

  if not result.file.open(path, mode, bufSize):
    raise newException(EIO, "Failed to open file")

  for line in result.file.lines():
    inc(result.num_lines)


proc readToEnd(log: TLog) =
  while not log.file.endOfFile:
    discard log.file.readLine()


proc close*(log: TLog) =
  ## Close the log
  # Read to end
  log.readToEnd()
  log.file.flushFile()
  log.file.close()
  log.file = nil


proc write*[T](log: TLog, value: T): string {.discardable.} =
  ## Write a line to the end of the log
  #serialize value
  result = $$value
  reset_write(log)
  log.file.writeln(result)
  inc(log.num_lines)


proc read*(log: TLog, T: typedesc): T =
  ## Read a single line from the log (starting at the beginning)
  reset_read(log)
  if not log.file.endOfFile:
    return to[T](log.file.readLine())


proc reset*(log: TLog) =
  ## Set log position at the start
  log.file.setFilePos(0)


proc flush(log: TLog) =
  ## Flush the log, writing to disk
  log.file.flushFile()


iterator lines*(log: TLog, T: typedesc): T =
  ## Iterate through each line of the log
  reset_read(log)
  for line in log.file.lines():
    yield to[T](line)


proc truncate*(log: TLog) =
  ## Truncates the log file
  log.close()
  if not log.file.open(log.path, fmWrite, 0):
    raise newException(EIO, "Failed to open file")
  log.close()
  if not log.file.open(log.path, log.mode, 0):
    raise newException(EIO, "Failed to open file")
  log.num_lines = 0


proc rollover*(log: Tlog, spare: int = 0, preserve = true) =
  ## Rolls over log to new file, appending .# to old filename before extension
  ## The last `spare` lines will be kept in current log
  var verFile: TFile
  var idx = 1

  if preserve:
    var info = splitFile(log.path)

    #Generate a new .ver filename
    var verName: string
    while true:
      verName = changeFileExt(log.path, $idx & info.ext)
      if not existsFile(verName): break
      inc(idx)

    #Open `.ver`
    verFile = system.open(verName, fmWrite)

  #Reset position of current file and copy all lines to .ver file
  log.reset()

  var buffer: seq[string]

  if spare > 0:
    buffer = newSeq[string]()

  idx = 0
  for line in log.file.lines():
    if preserve:
      verFile.writeln(line)

    if spare > 0:
      buffer.add(line)

    inc(idx)

  #Truncate log and write buffer back to log file
  log.truncate()
  log.num_lines = 0

  if spare > 0:
    for i in max(0, buffer.len-spare) .. buffer.len-1:
      log.file.writeln(buffer[i])
      inc(log.num_lines)

  #Close verFile
  if preserve:
    verFile.close()


when isMainModule:

  type TComplex = object
    content: string
    value1: int
    value2: tuple[x: int, y: int]

  echo "opening log"
  var log = open("log.db")

  echo "truncating log"
  log.truncate()

  echo "writing to log (1)"
  log.write("Hello world!")

  echo "writing to log (2)"
  var complex = TComplex(content: """Hello world!
    This is a test!
    of multiline""", value1: 5)

  log.write(complex)
  log.close()

  log = open("log.db")
  echo "reading from log (1)"
  echo log.read(string)
  #assert read[string](log) == "Hello world!"
  assert log.read(TComplex) == complex


  echo "iterating over log"
  log.truncate()
  log.write("Hello 1")
  log.write("Hello 2")
  log.write("Hello 3")
  log.write("Hello 4")

  assert log.num_lines == 4

  log.reset()

  var i = 1
  for line in log.lines(string):
    assert line == "Hello " & $i
    inc(i)


  echo "rolling over log"
  for take in 0..6:
    var remove = log.num_lines - take
    removeFile("log.1.db")
    log.rollover(take)

    assert log.num_lines == min(log.num_lines, take)

    i = max(0, remove)
    for line in log.lines(string):
      assert line == "Hello " & $(i + 1)
      inc(i)


  echo "closing log"
  log.close()
  removeFile("log.1.db")
  removeFile("log.db")