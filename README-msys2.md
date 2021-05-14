# Using ngdevkit natively on the Windows platform

The ngdevkit toolchain can be compiled natively and used as any
other Windows executable by means of the [MSYS2][msys2] environment.
[MSYS2][msys2] is the minimal POSIX-like environment that makes
the building of ngdevkit feasible on the Windows platform.

Once built, the resulting binaries are fully Native Windows binaries
that do not have any runtime dependencies on MSYS2. For example,
the GnGeo emulator does not depend on MSYS2 to be run. However, the
MSYS2 environment itself is still super useful as a development
environment, for instance to build the [example ROMs][examples].


## Prepare your environment for compilation

Building ngdevkit on Windows currently requires two big dependencies:
the [MSYS2][msys2] environment to build the toolchain, and a [Python 3
release for Windows][pywin] from https://www.python.org. The latter is
needed because that is currently the only way to install a pre-built
[PyGame][pygame] on Windows, which is a dependency of ngdevkit.


### Install Python and PyGame

Download the [Python 3 binary release][pywin] according to your
Windows platform, run the installer, and remember where you installed
your Python environment. For the sake of the example, this document
assumes that the Python 3 interpreter is installed for user `ngdevkit`
in:

    C:/Users/ngdevkit/AppData/Local/Programs/Python/Python39/python

Once the Python environment is installed, install a pre-built version
of PyGame with pip:

    C:/Users/ngdevkit/AppData/Local/Programs/Python/Python39/python -m pip install pygame

Your python environment is now ready to be used to compile ngdevkit


### Install MSYS2

To build ngdevkit, we rely on MSYS2 to provide the necessary C
development tools and generate native Windows executables.

Download the [MSYS2 installer][msys2] and install the MSYS2
environment locally. For the sake of the example this document assumes
that you installed it in the default location:

    C:\msys64

MSYS2 has two different runtimes:
  - The MSYS2 runtime, which is a minimal POSIX-like environment
  - The MinGW-w64 runtime, which is the full Windows-native runtime

Ngdevkit is built for Windows, so it targets the MinGW-w64 runtime.
However, in order to compile it successfully, you still need to run
the compilation in the MSYS2 runtime, as this runtime will deal
automatically with file path translation from POSIX to Windows.

Start a MSYS2 shell by running "MSYS2 MSYS" from the Start menu.
Alternatively, you can also start the shell from `cmd.exe` or from
PowerShell with:

    C:\msys64\usr\bin\bash.exe -l

Once you are in a MSYS2 shell, make sure your MSYS2 installation
is up-to-date with:

    pacman -Syuu


## Compiling the devkit

In a MSYS2 shell, first install all the ngdevkit dependencies:

    pacman -S git msys2-runtime-devel mingw-w64-x86_64-toolchain
    pacman -S msys2-w32api-headers msys2-w32api-runtime windows-default-manifest
    pacman -S autoconf autoconf-archive automake pkgconf make tar zip unzip
    pacman -S mingw-w64-x86_64-zlib mingw-w64-x86_64-SDL2 mingw-w64-x86_64-glew mingw-w64-x86_64-nsis
    pacman -S gmp-devel isl-devel mpc-devel mpfr-devel texinfo
    pacman -S flex bison expat gettext ncurses-devel zlib-devel mingw-w64-x86_64-boost
    # dependencies for the example ROMs
    pacman -S rsync mingw-w64-x86_64-sox mingw-w64-x86_64-imagemagick


You can now compile the entire devkit. You just have to pass
the location of the Python 3 distribution you downloaded earlier to
the configure script. Note that the path has to be passed in the
MSYS2 path format:

    autoreconf -iv
    ./configure --prefix=$PWD/local --enable-msys2 --with-python=/c/Users/ngdevkit/AppData/Local/Programs/Python/Python39/python
    make
    make install


The most tedious part is over! you then need to configure your
environment to add the built binaries to your `PATH`. You can do so
automatically with:

    eval $(make shellinit)


Congratulations! You are now ready to experiment with the devkit and
build the example ROMs:

    cd examples
    # make sure the environment variable are set
    eval $(make shellinit)
    # ensure Windows-native binaries are available in PATH
    export PATH=/mingw64/bin:$PATH
    autoreconf -I/mingw64/share/aclocal -iv
    # build the example ROMs
    ./configure --enable-msys2 --with-python=/c/Users/ngdevkit/AppData/Local/Programs/Python/Python39/python
    make

Look at [the main README](README.md) file for more details on
how to run the examples and the debugger.


[msys2]: https://www.msys2.org
[examples]: https://github.com/dciabrin/ngdevkit-examples
[pywin]: https://www.python.org/downloads/windows
[pygame]: https://www.pygame.org
