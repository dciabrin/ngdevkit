# Building ngdevkit from source on macOS

Building the devkit for macOS requires [brew][brew], the macOS
package manager. Please make sure you installed it and upgraded
it before proceeding to the compilation of ngdevkit.

Brew allows you to install all the packages that ngdevkit depends on.
If brew is up to date on your system, it should install pre-built
packages (called bottles), so most of the time will be spent in
compiling the devkit itself and not its dependencies.

You will need XCode, and GNU Make 4.x. Please note that the version of
GNU Make shipped with XCode is too old for ngdevkit, so you need to
install it from brew and use `gmake` instead of `make` as explained
later in this documentation.

The devkit uses Python 3, which is installed globally in macOS but
also in brew. To make sure you are installing python dependencies
in the right python distribution, you need to have brew's python
first in your PATH.


## Pre-requisite

In order to build the devkit you need autoconf, autoconf-archive and
GNU Make 4.x, and various additional dependencies to build the
toolchain modules such as GCC and SDCC. The devkit tools uses Python 3
and various dependencies (such as pillow and yaml). The emulator
requires SDL 2 and optionally OpenGL libraries.

The examples require ImageMagick for all the graphics
trickery and sox for audio conversion purpose.

Make sure that `brew` is in your PATH and its environment variables are
set up properly. By default, brew is installed in `/usr/local/bin/brew`
on Intel macs, and in `/opt/homebrew/bin/brew` on ARM macs. If `brew`
is not found in your PATH, you must initialize it with:

    eval $(/opt/homebrew/bin/brew shellenv)
    # Intel macs would use /usr/local/bin/brew shellenv

Then, ngdevkit's dependencies are installed as follows:

    brew update
    brew install gmake
    brew install python3 pillow
    # you need a package from pip, either in a virtual env or system-wide, e.g.:
    # $(brew --prefix python)/libexec/bin/pip install ruamel.yaml --break-system-packages
    brew deps gcc | xargs brew install
    brew deps sdcc | xargs brew install
    # dependencies for the example ROMs
    brew install autoconf-archive
    brew install glew sdl2 sdl2_image
    brew install zip imagemagick sox

Note that older version of the devkit and its example ROMs depended
on PyGame, which has now been replaced by pillow. So please make
sure to use the latest version of ngdevkit-examples for building ROMs.

## Building the toolchain

In order to build ngdevkit, the installed brew dependencies must
be available to the compiler, so you must add brew's PATH into
your build flags manually:

    HOMEBREW_PREFIX=$(brew --prefix)
    export CFLAGS="-I${HOMEBREW_PREFIX}/include${CFLAGS+ ${CFLAGS}}"
    export CXXFLAGS="-I${HOMEBREW_PREFIX}/include${CXXFLAGS+ ${CXXFLAGS}}"
    export CPPFLAGS="-I${HOMEBREW_PREFIX}/include${CPPFLAGS+ ${CPPFLAGS}}"
    export LDFLAGS="-L${HOMEBREW_PREFIX}/lib -Wl,-rpath,${HOMEBREW_PREFIX}/lib${LDFLAGS+ ${LDFLAGS}}"

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
