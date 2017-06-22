#!/usr/local/bin/python3.5 -u
import sys
import re
# Copyright:examples/2/echonl.0.pl  examples/2/echonl.1.pl
# Demon for foreach contain 'ARGV', and for loop (like in c)
# and regexes(// and s///), 4 operators for array(pop, push, shift, unshift)
if len(sys.argv) - 2 != -1:
    for arg in sys.argv[1:]:
        pr = arg
        pr = re.sub(r'[aeiou]', '', pr)
        print(pr)
    elements = []
    for i in range(len(sys.argv) - 2 + 1):
        elements.append(sys.argv[i + 1])
    a = 0
    while a < 15:
        print("-", end = '')
        a += 1
    print()
    b = elements.pop()
    print("Pop %s" % (b))
    elements = [b] + elements
    print("Unshift %s" % (b))
    b = elements[0]
    del elements[0]
    print("Shift %s" % (b))
    m = re.match(r'[0-9]', b)
    if m:
        print("Input contains number")
    else:
        print("Input not contains number")
else:
    print("Nothing input")
