# Compiling ngdevkit on the Windows platform

Compiling the devkit for Windows 10 is supported via [WSL][wsl]:

   * The devkit generates Linux binaries that can be used from your
     Linux environment or called like a regular Windows command via
     WSL's [interoperability wrapper][interop].

   * The GnGeo emulator is a native Windows GUI application. You
     can call it from both Linux and Windows and don't need a
     X server to run it.

   * The source-level debugging extension is not available yet.

You need to run a couple of manual steps before being able to compile
the devkit. This documentation explains how to compile ngdevkit with
Ubuntu on Windows.

## Pre-requisite

### Make sure you have an available WSL environment

Follow the
[WSL install documentation](https://docs.microsoft.com/en-us/windows/wsl/install-win10)
to enable the WSL subsystem on your Windows host.

Then go on the Windows store and choose a Linux distribution to
install on your Windows 10 host. This documentation uses Ubuntu 16.04,
but any other `apt`-based distribution should work the same.

## Building the devkit

### Configure the package repositories

Edit `/etc/apt/sources.list` to make the source packages from `main`
and `universe` repositories are available to apt. They are used to
resolve the packages that need to be installed to build gcc and
sdcc. Those two lines should be uncommented in
`/etc/apt/sources.list`:

    deb-src http://archive.ubuntu.com/ubuntu/ xenial main restricted
    deb-src http://archive.ubuntu.com/ubuntu/ xenial universe

### Install the dependencies

Install the packages required to build the devkit's compilers and
tools:

    sudo apt-get update
    sudo apt-get install gcc curl unzip imagemagick
    GCC_VERSION_PKG=$(apt-cache depends gcc | awk '/Depends.*gcc/ {print $2}')
    sudo apt-get build-dep $GCC_VERSION_PKG
    sudo apt-get build-dep sdcc
    sudo apt-get install libsdl2-dev
    sudo apt-get install python-pygame
    sudo apt-get install automake
    sudo apt-get install autoconf-archive

Then install the mingw cross-compiler to build a native GnGeo binary,
and install GnGeo's DLL dependencies:

    sudo apt-get install mingw-w64
    sudo apt-get install libz-mingw-w64-dev

### Download SDL2 runtime and development files

You need to download the SDL2 development files (header, library,
pkgconfig) and the redistributable SDL2 runtime binary
(`SDL2.dll`) from the [SDL2 website](https://www.libsdl.org/download-2.0.php).
For example:

    cd $HOME
    curl -LO https://www.libsdl.org/release/SDL2-devel-2.0.8-mingw.tar.gz
    curl -LO https://www.libsdl.org/release/SDL2-2.0.8-win32-x64.zip

Extract the SDL dll somewhere and remember the location of that file
for later:

    cd $HOME
    unzip SDL2-2.0.8-win32-x64.zip
    # this yields a file $HOME/SDL2.dll

Extract the development files and install the mingw-specifc files
into system's default location:

    tar xf SDL2-devel-2.0.8-mingw.tar.gz
    sudo cp -af SDL2-2.0.8/i686-w64-mingw32 SDL2-2.0.8/x86_64-w64-mingw32 /usr/local

Note: even if Ubuntu's mingw package installs in `/usr`, SDL2 expects
mingw to be located in `/usr/local`; so extract into that destination
path, and let GnGeo autodetect it automatically during compilation.

### Download GLEW runtime and development files

As an optional requirement, if you want to enable the GLSL blitter in
GnGeo (which allows you to use libretro's pixel shaders for
rendering), you need to download GLEW's headers and pre-compiled
binaries from the [GLEW website](http://glew.sourceforge.net/). For
example:

    cd $HOME
    curl -LO https://downloads.sourceforge.net/project/glew/glew/2.1.0/glew-2.1.0-win32.zip

Then extract the GLEW files somewhere and remember that path for
later, including the name of the extracted directory:

    cd $HOME
    unzip glew-2.1.0-win32.zip
    # this yields a directory $HOME/glew-2.1.0

Note that the minimal OpenGL requirement for the GLSL backend is
version 3.2 or above. Version 3.1 is not enough, so hardware with
an old integrated chipset probably won't work.


### Building the toolchain

Unlike other platforms, a native Windows 10 GnGeo requires all
its files to be located under a common directory. You need to
configure that GnGeo installation directory directly in file
`Makefile.config`. For example:

    GNGEO_INSTALL_PATH=/mnt/c/Users/ngdevkit/Desktop/gngeo

Note: it's a good idea to choose a directory under `/mnt/c` if you
want to run GnGeo easily from the Windows explorer.

You also need to update `Makefile.config` to specify the location of
file `SDL2.dll` that you extracted previously. This file will be
copied to the GnGeo installation directory automatically when building
the devkit. For example:

    SDL2_DLL=/home/ngdevkit/SDL2.dll

If you downloaded GLEW and want to enable the GLSL blitter backend,
update `Makefile.config` to specify the location of the extracted
GLEW directory. That directory provides the necessary header files
for compilation, and provides the runtime glew32.dll which will be
copied to the GnGeo installation directory automatically. For
example:

    GLEW_BIN_PATH=/home/ngdevkit/glew-2.1.0

Once this is done, you can build the devkit by using the dedicated
mingw makefile:

    make -f Makefile.mingw

And voilà! You can now use the devkit and the emulator as described
in [the main README](README.md) file.

[wsl]: https://docs.microsoft.com/en-us/windows/wsl/install-win10
[interop]: https://docs.microsoft.com/en-us/windows/wsl/interop
