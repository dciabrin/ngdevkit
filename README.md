# ngdevkit, open source development for Neo-Geo

![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macos%20%7C%20windows-lightgrey)
[![License: LGPL v3](https://img.shields.io/badge/License-LGPL_v3-green.svg)](https://www.gnu.org/licenses/lgpl-3.0)
[![Fedora](https://img.shields.io/badge/Fedora-37%20|%2038%20|%20Rawhide-informational?logo=Fedora&logoColor=white)](https://copr.fedorainfracloud.org/coprs/dciabrin/ngdevkit/monitor)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-Jammy%20|%20Kinetic-informational?logo=Ubuntu&logoColor=white)](https://code.launchpad.net/~dciabrin/ngdevkit/+git/ngdevkit)
[![Homebrew](https://img.shields.io/badge/Homebrew-11%20|%2012-informational?logo=Homebrew&logoColor=white)](https://github.com/dciabrin/homebrew-ngdevkit)
[![MSYS2](https://img.shields.io/badge/MSYS2-ucrt64-informational?logo=Windows&logoColor=white)](https://github.com/dciabrin/msys2-ngdevkit)


## Overview

ngdevkit is a C software development kit for the Neo-Geo
AES or MVS hardware. It includes:

   * A toolchain for cross compiling to m68k, based on GCC
     11.4 and newlib 4.0 for the C standard library.

   * C headers for accessing the hardware. The headers follow the
     naming convention found at the [NeoGeo Development Wiki][ngdev].

   * Helpers for declaring ROM information (name, DIP, interrupt
     handlers...)

   * A C and ASM cross-compiler for the z80 (SDCC 4.2), for developing
     your music and sound driver.

   * An open source replacement BIOS for testing your ROMs
     under you favorite emulator.

   * Tools for managing graphics for fix and sprite ROM.

   * Support for source-level debugging with GDB!

   * A modified version of the emulator [GnGeo][gngeo], with support
     for libretro's GLSL shaders and remote debugging!

   * A simple scanline pixel shader for a nice retro look!



## How to use the devkit

### Installing pre-built binary packages

There are nightly packages available for Linux, macOS and Windows, so
you get the most up-to-date devkit without recompiling the entire
toolchain any time there is an update in git.

#### Linux

If you are running an Ubuntu or Debian distribution, you can install
pre-built debian packages from the ngdevkit PPA, as well as a couple
of dependencies for the examples ROMs:

    add-apt-repository -y ppa:dciabrin/ngdevkit
    apt-get update
    apt-get install ngdevkit ngdevkit-gngeo
    # the remaining packages are only requred for the examples
    apt-get install pkg-config autoconf zip imagemagick sox libsox-fmt-mp3

If you are running a Fedora distribution, pre-built packages are
available in COPR, and can be installed with the following commands:

    dnf copr enable dciabrin/ngdevkit
    dnf install ngdevkit ngdevkit-gngeo
    # the remaining packages are only requred for the examples
    dnf install install pkg-config autoconf zip ImageMagick sox

#### macOS

If you are running on macOS, you can install [brew][brew]
packages, available in the ngdevkit tap:

    # If you haven't done it yet, make sure XCode is installed first
    sudo xcode-select --install
    # If needed, init brew and its environment variables
    eval $(/opt/homebrew/bin/brew shellenv)
    # install ngdevkit
    brew tap dciabrin/ngdevkit
    brew install ngdevkit ngdevkit-gngeo
    # make sure you use brew's python3 in your shell
    export PATH=$HOMEBREW_PREFIX/opt/python3/bin:$PATH
    pip3 install pygame
    # the remaining packages are only required for the examples
    brew install pkg-config autoconf automake zip imagemagick sox

Some macOS versions are not currently pre-built (macOS 11 Intel and
M1), as our CI provider doesn't currently offer free hosted agents
yet, so it might take some time to install the packages.

#### Windows

You can run ngdevkit natively on Windows, via the [MSYS2][msys2]
environment. Pre-built ngdevkit packages are available for the ucrt64
subsystem of MSYS2. To use them, start a MSYS2 shell for ucrt64, and
configure the pacman repository as follows:

    MSYSTEM=UCRT64 /usr/bin/bash -l
    echo -e "\n[ngdevkit]\nSigLevel = Optional TrustAll\nServer = https://dciabrin.net/msys2-ngdevkit/\$arch" >> /etc/pacman.conf
    
    # install pacboy with `pacman -S pactoys` if necessary
    pacboy -Sy
    pacboy -S ngdevkit:u ngdevkit-gngeo:u
    # the remaining packages are only required for the examples
    pacboy -S autoconf automake make zip imagemagick:u sox:u

An old version of ngdevkit supported Windows 10 via [WSL][wsl], but it
is now deprecated in favour of the native MSYS2 environment. Likewise,
we no longer build nightly packages for MSYS2's mingw64 subsystem,
ucrt64 is the only supported subsystem for ngdevkit.

### Build the included examples

The devkit comes with a series of examples to demonstrate how to use
the compiler and tools. Once ngdevkit packages are installed, you can
clone the [ngdevkit-examples][examples] repository:

    git clone --recursive https://github.com/dciabrin/ngdevkit-examples examples

And build all the examples with the following commands if you are running
on Linux or Windows/MSYS2:

    cd examples
    autoreconf -iv
    ./configure
    make

For macOS, make sure you use brew's python3 and gmake:

    cd examples
    export PATH=$HOMEBREW_PREFIX/opt/python3/bin:$PATH
    autoreconf -iv
    ./configure
    gmake

For any platform that supports docker

```shell
make -f Makefile.docker shell
```

### Running the emulator

Once you have built the examples, go into a subdirectory to
test the compiled example and run GnGeo from the makefile:

    cd examples/01-helloworld
    make gngeo
    # or run "make gngeo-fullscreen" for a more immersive test

If you are running a recent macOS, [System Integrity Protection][sip]
may prevent you from running GnGeo from gmake, so you may need to run
it from your terminal:

    eval $(gmake -n gngeo)


### Debugging your programs

The devkit uses a modified version of GnGeo which supports remote
debugging via GDB. In order to use that feature on the example ROM,
you first need to start the emulator in debugger mode:

    cd examples/01-helloworld
    # example ROM is named puzzledp
    ngdevkit-gngeo -i rom puzzledp -D

With argument `-D`, the emulator waits for a connection from a GDB
client on port `2159` of `localhost`.

Then, run GDB with the original ELF file as a target instead of the
final ROM file:

    cd examples/01-helloworld
    m68k-neogeo-elf-gdb rom.elf

The ELF file contains all the necessary data for the debugger,
including functions, variables and source-level line information.

Once GDB is started, connect to the emulator to start the the debugging
session. For example:

    (gdb) target remote :2159
    Remote debugging using :2159
    0x00c04300 in ?? ()
    (gdb) b main.c:52
    Breakpoint 1 at 0x57a: file main.c, line 52.
    (gdb) c



### Building the devkit from sources

If you want to build from source, this repository is the main entry
point: it provides the necessary tools, headers, link scripts and open
source BIOS to build your homebrew roms.  The rest of the devkit is
split into separate git repositories that are automatically cloned at
build time:

   * [ngdevkit-toolchain][toolchain] provides the GNU toolchain,
     newlib, SDCC and GDB.

   * [gngeo][gngeo] and [emudbg][emudbg] provide a custom GnGeo with
     support for GLSL shaders and remote gdb debugging.

   * [ngdevkit-examples][examples] shows how to use the devkit and how
     to program the Neo Geo hardware. It comes with a GnGeo
     configuration to run your roms with a "CRT scanline" pixel
     shader.

There are dedicated instructions to build ngdevkit for [Linux](README-linux.md),
[macOS](README-macos.md) or [Windows](README-msys2.md).



## History

This work started a _long_ time ago (2002!) and was originally called
neogeodev on [sourceforge.net][sfnet]. Since then, a community has
emerged at [NeoGeo Development Wiki][ngdev], and it is a real treasure
trove for Neo-Geo development. Coincidentally, they are hosted at
[`neogeodev.org`][ngdev], so I decided to revive my original project on github
as `ngdevkit` :P


## Acknowledgments

Thanks to [Charles Doty][cdoty] for his `Chaos` demo, this is how I
learned about booting the console, and fiddling with sprites!

Thanks to Mathieu Peponas for [GnGeo][gngeo] and its effective
integrated debugger. Thanks to the contributors of the [mame][mame]
project for such a great emulator.

A big thank you goes to Furrtek, ElBarto, Razoola...and all the NeoGeo
Development Wiki at large. It is an amazing collection of information,
with tons of hardware details and links to other Neo-Geo homebrew
productions!


## License

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this program. If not, see
<http://www.gnu.org/licenses/>.


[toolchain]: https://github.com/dciabrin/ngdevkit-toolchain
[emudbg]: https://github.com/dciabrin/emudbg
[examples]: https://github.com/dciabrin/ngdevkit-examples
[ngdev]: http://wiki.neogeodev.org
[sfnet]: http://neogeodev.sourceforge.net
[cdoty]: http://rastersoft.net
[gngeo]: https://github.com/dciabrin/gngeo
[mame]: http://mamedev.org/
[sip]: https://support.apple.com/en-us/HT204899
[wsl]: https://docs.microsoft.com/en-us/windows/wsl/install-win10
[brew]: https://brew.sh
[msys2]: https://www.msys2.org
[pywin]: https://www.python.org/downloads/windows
