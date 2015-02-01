# ngdevkit, open source development for Neo-Geo

ngdevkit is a C/C++ software development kit for the Neo-Geo
AES or MVS hardware. It includes:

   * A toolchain for cross compiling to m68k, based on GCC
     4.9 and newlib for the C standard library.

   * C headers for accessing the hardware. The headers follow the
     naming convention found at the [NeoGeo Development Wiki][ngdev].

   * Helpers for declaring ROM information (name, DIP, interrupt
     handlers...)

   * An open source replacement BIOS for testing your ROMs
     under you favorite emulator.

   * Tools for managing graphics for fix and sprite ROM.



## How to compile the devkit

### Pre-requisite

You need to install various dependencies to build gcc, and ImageMagick
for all the graphics trickery. On a Debian-derived distro, this is
done via:

    apt-get build-dep gcc
    apt-get install imagemagick

If running OS X, you will need XCode and brew:

    brew deps gcc | xargs brew install
    brew install imagemagick

### Building the toolchain

You may want to change `Makefile.config` to select a GNU mirror which
is close to you for maximum download speed. Then, build the entire
toolchain with:

    make

You can see how to use the toolchain by compiling demos in directory
`examples`. For instance:

    cd examples/01-helloworld
    make
    make nullbios

This will compile the example and copy the replacement BIOS into
directory `rom`. You can now run it with you favorite emulator.

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


[ngdev]: http://wiki.neogeodev.org
[sfnet]: http://neogeodev.sourceforge.net
[cdoty]: http://rastersoft.net
[gngeo]: https://code.google.com/p/gngeo
[mame]: http://mamedev.org/
