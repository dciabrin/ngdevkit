#!/bin/bash
set -eu
if [ -n "$PY3PATH" ]; then
    export PATH=$PY3PATH:$PATH
fi
autoreconf -iv
./configure \
    --prefix=/mingw64 \
    --build=x86_64-w64-mingw32 \
    --host=x86_64-w64-mingw32 \
    --target=x86_64-w64-mingw32 \
    --enable-external-toolchain \
    --enable-external-emudbg \
    --enable-external-gngeo \
    --enable-examples=no
make
make install
