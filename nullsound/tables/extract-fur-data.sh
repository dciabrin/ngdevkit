#!/bin/sh

set -e

function upper {
    echo $1 | tr '[:lower:]' '[:upper:]'
}

function error {
    echo "$1" >&2
    exit 1
}

function check_dep {
    if [ -z "$2" ] || ! `which "$2" &>/dev/null`; then error "Cannot find a working $1 ('$2' not in PATH)"; fi
}

CH=${1:-fm}
HW=${2:-mvs}

# Defaults that can be overriden
: ${PYTHON:=python3}
: ${FURNACE:=furnace}
: ${VGMD:=vgmd}

check_dep "python" "$PYTHON"
check_dep "Furnace" "$PYTHON"
check_dep "VGMd" "$VGMD"

TMPDIR=tmp
VGMDIR=$TMPDIR/vgm/$HW/$CH
OUTDIR=.
mkdir -p $TMPDIR $VGMDIR $OUTDIR

FUR=fur/nss-$CH-$HW.fur
WORKFUR=$TMPDIR/work.fur
OUT=fur_${CH}_$HW.py

if [ ! -f "$FUR" ]; then error "Cannot process Furnace module '$FUR', aborting."; fi

# Unzip input Furnace module for further processing
$PYTHON -c 'import zlib;data=zlib.decompress(open("'$FUR'","rb").read());open("'$WORKFUR'","wb").write(data)'

# Find binary offset of the pitch FX present in the input Furnace module
SEEK=$($PYTHON -c "print(open('"$WORKFUR"','rb').read().find(b'\xe5\x80')+1)")

echo "Extracting Furnace settings for all possible detuned/pitched notes of `upper $CH` channel (`upper $HW` variant)"
echo "furdata=[()]*128" > $OUTDIR/$OUT
off=$($PYTHON -c 'print("\n".join(["\\x%x"%x for x in range(0x80,0x100)]))')
for o in $off; do
    echo -n .
    printf $o | dd of=$WORKFUR bs=1 seek=$SEEK conv=notrunc status=none
    $FURNACE --loops 0 -vgmout $VGMDIR/${o#\\x}.vgm $WORKFUR &>/dev/null
    if [ "$CH" = "fm" ]; then
        $VGMD $VGMDIR/${o#\\x}.vgm vgm _ | sed -ne 's/.*HEX: \(.....\).*/\1,/p' | awk 'BEGIN {print "furdata[0x'${o#\\x}'-0x80]=("} {print $0} END {print ")"}' >> $OUTDIR/$OUT
    else
        $VGMD $VGMDIR/${o#\\x}.vgm vgm _ | grep 'SSG.*tune.*Hz' | sed 's/.*)//' | awk 'BEGIN {print "furdata[0x'${o#\\x}'-0x80]=("} {print "0x"$1","} END {print ")"}' >> $OUTDIR/$OUT
    fi
done
echo -e "\nData extracted and saved in $OUTDIR/$OUT"
