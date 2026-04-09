import sys
import re

ram={}
with open(sys.argv[1],"r") as f:
    for l in f.readlines():
        m = re.match(r' *0000(F...) *(_state[^ ]*_(begin|end)) *nullsound', l)
        if m:
            ram[m.group(2)] = m.group(1)
range_keys=list(dict.fromkeys([re.sub(r"_(begin|end)", "", x) for x in ram]))
for k in range_keys:
    start, end = ram[k+"_begin"], ram[k+"_end"]
    # print(k, start, end)
    if start[0:2] != end[0:2]:
        sys.exit("range \"%s\" crosses 256 bytes boundaries: [%s, %s]"%(k, start, end))
