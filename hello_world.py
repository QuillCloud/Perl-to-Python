#!/usr/local/bin/python3.5 -u
import sys
import re
# Copyright: examples/4/size.pl examples/4/odd0.pl
# Demo for change varible type of input, like change string to float
# also show $#array, regex s///, change value in array
print("Enter number:")
a = float(sys.stdin.readline())
if a < 0:
    print("negative")
elif a >=0:
    if a % 2 == 0:
        print("Even")
    else:
        print("Odd")
print("Enter string(number will be replaced by ?):")
b = sys.stdin.readline()
b = b.rstrip()
bb = b.split(' ')
l = len(bb) - 1 + 1
print("Number of words: %s" % (l))
for i in range(len(bb) - 1 + 1):
    bb[i] = re.sub(r'[0-9]', '?', bb[i])
print(' '.join(bb))
