#!/bin/bash
set -eu
if [ -n "$PY3PATH" ]; then
    export PATH=$PY3PATH:$PATH
fi
autoreconf -iv
./configure \
    --prefix=${MSYSTEM_PREFIX} \
    --build=${MSYSTEM_CHOST} \
    --host=${MSYSTEM_CHOST} \
    --target=${MSYSTEM_CHOST} \
    --enable-external-toolchain \
    --enable-external-emudbg \
    --enable-external-gngeo
make
make install
