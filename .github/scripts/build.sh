#!/bin/bash
set -eu
if [ -n "$PY3PATH" ]; then
    export PATH=$PY3PATH:$PATH
fi
autoreconf -iv
./configure --prefix=${PREFIX} --enable-external-toolchain --enable-external-emudbg --enable-external-gngeo
MAKE=$(which gmake make | head -1)
$MAKE
sudo $MAKE install
