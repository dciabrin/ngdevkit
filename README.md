# ngdevkit, open source development for Neo-Geo

ngdevkit is a C/C++ software development kit for the Neo-Geo
AES or MVS hardware. It includes:

   * A toolchain for cross compiling to m68k, based on GCC
     5.5 and newlib for the C standard library.

   * C headers for accessing the hardware. The headers follow the
     naming convention found at the [NeoGeo Development Wiki][ngdev].

   * Helpers for declaring ROM information (name, DIP, interrupt
     handlers...)

   * A C and ASM cross-compiler for the z80 (SDCC 3.7), for developing
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

If you're running an Ubuntu or Debian distribution, you can install
pre-built nightly binary packages, so you get the most up-to-date
devkit without recompiling the entire toolchain at every update.

You need to enable the ngdevkit PPA and install a couple
of dependencies:

    add-apt-repository -y ppa:dciabrin/ngdevkit
    # if you're running Ubuntu 18.04 (Bionic), add the following ppa for PyGame
    # add-apt-repository -y ppa:thopiekar/pygame
    apt-get update
    apt-get install ngdevkit ngdevkit-gngeo
    apt-get install pkg-config autoconf zip imagemagick

If you're running on Windows 10, you can also use those pre-built
deb binaries with [WSL][wsl]. It is complemented by a pre-built
native version of GnGeo. Details on how to install and use them
are available in [a dedicated README](README-mingw.md).

If you're running on macOS, you can install pre-built [brew][brew]
packages, available in the ngdevkit tap:

    # If you haven't done it yet, make sure XCode is installed first
    sudo xcode-select --install
    brew tap dciabrin/ngdevkit
    brew install ngdevkit ngdevkit-gngeo
    # make sure you use brew's python3 in your shell
    export PATH=/usr/local/opt/python3/bin:$PATH
    pip3 install pygame==2.0.0.dev6
    # the remaining packages are required for the examples
    brew install pkg-config autoconf automake zip imagemagick

Once ngdevkit packages are installed, you can clone the
[ngdevkit-examples][examples] repository and build all the examples
with the following commands:

    git clone --recursive https://github.com/dciabrin/ngdevkit-examples examples
    autoreconf -iv
    ./configure
    make

You can learn how to use the devkit and how to build your first
Neo-Geo program by reading the dedicated examples/README.md.


### Building the devkit from sources

The devkit itself is a collection of various git repositories. This
repository is the main entry point: it provides the necessary tools,
headers, link scripts and open source bios to build your homebrew roms.
The rest of the devkit is split into separate git repositories that
are automatically cloned at build time:

   * [ngdevkit-toolchain][toolchain] provides the GNU toolchain,
     newlib, SDCC and GDB.

   * [gngeo][gngeo] and [emudbg][emudbg] provide a custom GnGeo with
     support for GLSL shaders and remote gdb debugging.

   * [ngdevkit-examples][examples] shows how to use the devkit and how
     to program the Neo Geo hardware. It comes with a GnGeo
     configuration to run your roms with a "CRT scanline" pixel
     shader.


#### Pre-requisite

In order to build the devkit you need autoconf, autoconf-archive and
GNU Make 4.x. The devkit tools uses Python 3 and PyGame. The emulator
requires SDL 2.0 and optionally OpenGL libraries. The examples require
ImageMagick for all the graphics trickery. Various additional
dependencies are required to build the toolchain modules such as GCC
and SDCC.

For example, on Debian Buster, you can install the dependencies with:

    apt-get install autoconf autoconf-archive automake gcc curl zip unzip imagemagick
    apt-get install libsdl2-dev
    apt-get install python3-pygame
    GCC_VERSION_PKG=$(apt-cache depends gcc | awk '/Depends.*gcc/ {print $2}')
    # make sure you have src packages enabled for dependency information
    echo "deb-src http://deb.debian.org/debian buster main" > /etc/apt/sources.list.d/ngdevkit.list
    apt-get update
    # install build-dependency packages
    apt-get build-dep $GCC_VERSION_PKG
    apt-get build-dep --arch-only sdcc
    # optional: install GLEW for OpenGL+GLSL shaders in GnGeo
    apt-get install libglew-dev

If running OS X, you will need XCode, brew and GNU Make 4.x. Please
note that the version of GNU Make shipped with XCode is tool old,
so you need to install it from brew and use `gmake` instead of `make`
as explained later in this manual. Install the dependencies with:

    brew install gmake
    brew install autoconf-archive
    brew install zip imagemagick
    brew install sdl2 sdl2_image
    brew install python3
    # make sure you use brew's python3 to install pygame
    export PATH=/usr/local/opt/python3/bin:$PATH
    pip3 install pygame==2.0.0.dev6
    brew deps gcc | xargs brew install
    brew deps sdcc | xargs brew install

Compiling the devkit for Windows 10 is supported via [WSL][wsl],
detailed setup and build instructions are available in the
[the dedicated README](README-mingw.md).


#### Building the toolchain

The devkit relies on autotools to check for dependencies and
autodetect the proper build flags. You can build the entire devkit
in your local git repository with:

    autoreconf -iv
    ./configure --prefix=$PWD/local
    make
    make install

If compiling on OS X, please use `gmake` instead of `make` as
the version of GNU Make shiped with XCode is too old (currently 3.x)
and the devkit won't compile with it.

## Building examples ROMs with the devkit

Bundled with the devkit is a series of examples that is automatically
downloaded when you build ngdevkit.

In order to build the examples, you need to have the devkit binaries
available in your path. This can be done automatically with:

    eval $(make shellinit)

This configures your environment variables to have access to all the
binaries from the toolchain, including the emulator and the debugger.
Then, you can just jump into the `examples` directory and let the
`configure` script autodetect everything for you:

    cd examples
    ./configure
    make

This will compile all the examples available in the directory.

### Running the emulator

Once you have built the examples, go into a subdirectory to
test the compiled example and run GnGeo from the makefile:

    cd examples/01-helloworld
    make gngeo
    # or run "make gngeo-fullscreen" for a more immersive test

If you're running a recent macOS, [System Integrity Protection][sip]
may prevent you from running GnGeo from make, so you may need to run
it from your terminal:

    eval $(make -n gngeo)

### Debugging your programs

The devkit uses a modified version of GnGeo which supports remote
debugging via GDB. In order to use that feature on the example ROM,
you first need to start the emulator in debugger mode:

    eval $(make shellinit)
    cd examples/01-helloworld
    # example ROM is named puzzledp
    ngdevkit-gngeo -i rom puzzledp -D

With argument `-D`, the emulator waits for a connection from a GDB
client on port `2159` of `localhost`.

Then, run GDB with the original ELF file as a target instead of the
final ROM file:

    eval $(make shellinit)
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
