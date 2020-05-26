# Using ngdevkit on the Windows platform

If you run Windows 10, you can consume or compile ngdevkit via [WSL][wsl],
the Windows Subsystem for Linux:

   * The devkit binaries are standard Linux executable that can be
     used from your Linux environment or called like a regular Windows
     command via WSL's [interoperability wrapper][interop].

   * The GnGeo emulator is a native Windows GUI application. You
     can call it from both Linux and Windows and don't need a
     X server to run it. You also gget all the advantage of native
     application, like for example hardware-accelerated OpenGL
     pixel shaders.

This documentation details the various steps you need to perform
depending on whether you want to install pre-built binaries of
ngdevkit and gngeo, or whether you want to build the entire devkit
from scratch.

## Pre-requisite

### Make sure you have an available WSL environment

Follow the
[WSL install documentation](https://docs.microsoft.com/en-us/windows/wsl/install-win10)
to enable the WSL subsystem on your Windows host.

Then go on the Windows store and choose a Linux distribution to
install on your Windows 10 host. This documentation uses Ubuntu 20.04,
but any other `apt`-based distribution should work the same.

## Installing pre-built binaries of ngdevkit

If you don't want to build the devkit yourself, you can just
install the regular .deb binaries from the ngdevkit PPA,
as mentionned in the main README.md:

    add-apt-repository -y ppa:dciabrin/ngdevkit
    # if you're running Ubuntu 18.04 (Bionic), add the following ppa for PyGame
    # add-apt-repository -y ppa:thopiekar/pygame
    apt-get update
    apt-get install -y ngdevkit
    # the following dependencies are for ngdevkit's examples
    apt-get install -y pkg-config autoconf zip imagemagick

Unlike regular ngdevkit on Linux, you need to install a windows-native
version of ngdevkit-gngeo. You can download the latest available
ngdevkit-gngeo installer at
https://github.com/dciabrin/gngeo/releases.

Look for the latest available nightly pre-release. One of its asset
will be called `setup-ngdevkit-gngeo-nightly.exe`. This is a NSIS
installer that will install a windows-native gngeo, and all its
dependencies: SDL2, OpenGL and GLEW.

Once those binaries are installed, you need to manually add
ngdevkit-gngeo in your `PATH` to run the examples. For example, if you
installed ngdevkit-gngeo in e.g. `C:\Users\ngdevkit\Desktop`, you need
to reference that path with the equivalent WSL mount point as follows:

    export PATH="/mnt/c/Users/ngdevkit/Desktop/gngeo":$PATH

You can know clone the examples and compile them with:

    git clone --recursive https://github.com/dciabrin/ngdevkit-examples examples
    autoreconf -iv
    ./configure --enable-mingw
    make

Look at [the main README](README.md) file for more details on
how to run the examples and the debugger.


## Building the devkit from scratch

### Configure the package repositories

Edit `/etc/apt/sources.list` to make the source packages from `main`
and `universe` repositories are available to apt. They are used to
resolve the packages that need to be installed to build gcc and
sdcc. Those two lines should be uncommented in
`/etc/apt/sources.list`:

    deb-src http://archive.ubuntu.com/ubuntu/ focal main restricted
    deb-src http://archive.ubuntu.com/ubuntu/ focal universe

### Install the dependencies

Install the packages required to build the devkit's compilers and
tools:

    # Ubuntu 18.04 (Bionic) needs the ppa below for PyGame in python3
    # add-apt-repository ppa:thopiekar/pygame
    sudo apt-get update
    sudo apt-get install gcc curl zip unzip imagemagick
    GCC_VERSION_PKG=$(apt-cache depends gcc | awk '/Depends.*gcc/ {print $2}')
    sudo apt-get build-dep $GCC_VERSION_PKG
    sudo apt-get build-dep --arch-only sdcc
    sudo apt-get install libsdl2-dev
    sudo apt-get install python3-pygame
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
configure ngdevkit to install GnGeo into a custom directory.
For example:

    GNGEO_DIR=/mnt/c/Users/ngdevkit/Desktop/gngeo

Note: it's a good idea to choose a directory under `/mnt/c` if you
want to run GnGeo easily from the Windows explorer.

At this point, if you downloaded all the dependencies in the home
directory as describe in the example above, you can build the
toolkit with:

    autoreconf -iv
    ./configure --prefix=$PWD/local --enable-mingw --with-sdl2=$HOME/SDL2.dll --with-glew=$HOME/glew-2.1.0 GNGEO_INSTALL_PATH=${GNGEO_DIR}
    make
    make install

The `install` target will copy all the Windows 10 dependencies in
the GnGeo directory: the `SDL2.dll`, a mingw-compiled `zlib.dll`,
and the optional GLEW library if you enabled the GLSL blitter
backend.

And voilà! You now have a devkit and a Windows-10-native GnGeo.
You can now build the various examples that come with the devkit
as follows:

    eval $(make shellinit)
    cd examples
    ./configure --enable-mingw
    make

Look at [the main README](README.md) file for more details on
how to run the examples and the debugger.

[wsl]: https://docs.microsoft.com/en-us/windows/wsl/install-win10
[interop]: https://docs.microsoft.com/en-us/windows/wsl/interop
