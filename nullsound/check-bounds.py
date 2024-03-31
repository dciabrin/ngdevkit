import sys
import re

ram={}
with open(sys.argv[1],"r") as f:
    for l in f.readlines():
        m = re.match(r' *0000(F...) *(_state[^ ]*) *nullsound', l)
        if m:
            ram[m.group(2)] = m.group(1)
range_keys=list(set([re.sub(r"_(start|end)", "", x) for x in ram]))
for k in range_keys:
    start, end = ram[k+"_start"], ram[k+"_end"]
    if start[0:2] != end[0:2]:
        sys.exit("range \"%s\" crosses 256 bytes boundaries: [%s, %s]"%(k, start, end))
