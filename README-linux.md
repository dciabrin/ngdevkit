# Building ngdevkit from source on Linux

## Pre-requisite

In order to build the devkit you need autoconf, autoconf-archive and
GNU Make 4.x, and various additional dependencies to build the
toolchain modules such as GCC and SDCC. The devkit tools uses Python 3
and various dependencies (such as pillow and PyYAML).
The emulator requires SDL 2 and optionally OpenGL libraries.

Note that older version of the devkit and its example ROMs depended
on PyGame, which has now been replaced by pillow. So please make
sure to use the latest version of ngdevkit-examples for building ROMs.

The examples require ImageMagick for all the graphics
trickery and sox for audio conversion purpose.

For example, on a recent Ubuntu version, you can install the dependencies with:

    apt-get install autoconf autoconf-archive automake gcc curl zip unzip
    apt-get install libsdl2-dev
    apt-get install python3-pil
    apt-get install libreadline-dev
    GCC_VERSION_PKG=$(apt-cache depends gcc | awk '/Depends.*gcc/ {print $2}')
    # make sure you have src packages enabled for dependency information
    echo "deb-src http://archive.ubuntu.com/ubuntu/ noble main restricted" > /etc/apt/sources.list.d/ngdevkit.list
    echo "deb-src http://archive.ubuntu.com/ubuntu/ noble universe" >> /etc/apt/sources.list.d/ngdevkit.list
    apt-get update
    # install build-dependency packages
    apt-get build-dep $GCC_VERSION_PKG
    apt-get build-dep --arch-only sdcc
    # optional: install GLEW for OpenGL+GLSL shaders in GnGeo
    apt-get install libglew-dev
    # dependencies for the example ROMs
    apt-get install imagemagick sox libsox-fmt-mp3

Debian users (for example Buster) would install the dependencies above
by updating the src packages URL as follows:

    echo "deb-src http://deb.debian.org/debian trixie main" > /etc/apt/sources.list.d/ngdevkit.list
    # the remaining dependencies are the same

## Building the toolchain

The devkit relies on autotools to check for dependencies and
autodetect the proper build flags. It is advised that you build
the entire devkit in a self-contained directory inside your
local git repository with:

    autoreconf -iv
    ./configure --prefix=$PWD/local
    make
    make install

Once the devkit is built, you then need to configure your environment
to add the built binaries to your `PATH`. You can do so automatically
with:

    eval $(make shellinit)


Congratulations! You are now ready to experiment with the devkit.
Please follow the [main README](README.md) for additional information
on how to download and build the example ROMs, run the emulator or
run the debugger.

