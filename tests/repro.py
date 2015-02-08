import os, subprocess, socket
from time import sleep

# Fields
files = [
    ("list.nim",     [ '15:22', '30:49', '59:20', '64:20' ]),
    ("memory.nim",   [ '9:24', '15:26', '37:35' ]),
    ("termtest.nim", [ '26:7', '37:9', '48:22' ])
]

# Methods
def linesplit(socket):
    buffer = socket.recv(4096)
    buffering = True
    while buffering:
        if "\n" in buffer:
            (line, buffer) = buffer.split("\n", 1)
            yield line + "\n"
        else:
            more = socket.recv(4096)
            if not more:
                buffering = False
            else:
                buffer += more
    if buffer:
        yield buffer

def startService(proj):
    # Start the server
    proc = subprocess.Popen(
        'nimsuggest --port:8088 "' + proj + '"',
        bufsize=0,
        stdout=subprocess.PIPE,
        universal_newlines=True,
        shell=True)
    print("Starting nimsuggest...")
    ensure_socket()
    print("nimsuggest running")
    return proc

def ensure_socket(secs=2, wait=.2):
    while True:
        sock = None
        try:
            sock = opensock()
            sock.close()
            return True
        except:
            secs -= wait
            if secs <= 0:
                print('nimsuggest failed to respond')
                return False
            sleep(wait)
            sock = None

def opensock():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect(("localhost", 8088))
    return s

def sendrecv(args, getresp = True):
    sock = None
    try:
        sock = opensock()
        sock.send(args + "\r\n")
        if getresp:
            for line in linesplit(sock):
                return line
            return ""
    except Exception as e:
        print(e)
    finally:
        if sock is not None:
            sock.close()

# Testbed
proc = startService(files[0][0])

try:
    while True:
        for i in files:
            (filepath, locs) = i
            fullpath = os.path.abspath(filepath)

            for loc in locs:
                sleep(.5)
                args = 'def "' + fullpath + '":' + loc
                print(args)
                result = sendrecv(args).rstrip()
                if not result:
                    print("No result.")
                else:
                    print(result)
                print("\n")

finally:
    # Kill the proc
    proc.terminate()
    print("nimsuggest killed")