#!/bin/bash
set -eu
if [ -n "$PY3PATH" ]; then
    export PATH=$PY3PATH:$PATH
fi
cd examples
export XDG_RUNTIME_DIR=$HOME
MAKE=$(which gmake make | head -1)
./configure && $MAKE
