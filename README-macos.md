# Building ngdevkit from source on macOS

Building the devkit for macOS requires [brew][brew], the macOS
package manager. Please make sure you installed it and upgraded
it before proceeding to the compilation of ngdevkit.

Brew allows you to install all the packages that ngdevkit depends on.
If brew is up to date on your system, it should install pre-built
packages (called bottles), so most of the time will be spent in
compiling the devkit itself and not its dependencies.

You will need XCode, and GNU Make 4.x. Please note that the version of
GNU Make shipped with XCode is tool old for ngdevkit, so you need to
install it from brew and use `gmake` instead of `make` as explained
later in this documentation.

The devkit uses Python 3, which is installed globally in macOS but
also in brew. To make sure you are installing python dependencies
in the right python distribution, you need to have brew's python
first in your PATH, as explained later in the document.


## Pre-requisite

In order to build the devkit you need autoconf, autoconf-archive and
GNU Make 4.x, and various additional dependencies to build the
toolchain modules such as GCC and SDCC. The devkit tools uses Python 3
and PyGame 2. The emulator requires SDL 2 and optionally OpenGL
libraries.

The examples require ImageMagick for all the graphics
trickery and sox for audio convertion purpose.

The dependencies are installed as follows:

    brew update
    brew install gmake
    brew install autoconf-archive
    brew install glew sdl2 sdl2_image
    brew install python3
    # make sure you use brew's python3 to install pygame
    export PATH=/usr/local/opt/python3/bin:$PATH
    pip3 install pygame
    brew deps gcc | xargs brew install
    brew deps sdcc | xargs brew install
    # dependencies for the example ROMs
    brew install zip imagemagick sox


## Building the toolchain

The devkit relies on autotools to check for dependencies and
autodetect the proper build flags. It is advised that you build
the entire devkit in a self-contained directory inside your
local git repository with:

    autoreconf -iv
    ./configure --prefix=$PWD/local
    gmake
    gmake install

Please note that the devkit is built with `gmake` which has been
installed by brew. This is because internally ngdevkit relies on
features of GNU Make that are only available from version 4.

Once the devkit is built, you then need to configure your environment
to add the built binaries to your `PATH`. You can do so automatically
with:

    eval $(make shellinit)


Congratulations! You are now ready to experiment with the devkit.
Please follow the [main README](README.md) for additional information
on how to download and build the example ROMs, run the emulator or
run the debugger.


[brew]: https://brew.sh
