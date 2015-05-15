import json
import time

with open('data.json') as data_file:
    data = json.load(data_file)

def convert():
    result = ""
    for i in range(1000):
        result = str(data)


print "Python"
t1 = time.time()
convert()
t2 = time.time()
print "  time:", t2 - t1, "s"
