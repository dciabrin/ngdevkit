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

### Install MSYS2

To build ngdevkit, we rely on MSYS2 to provide the necessary C
development tools and generate native Windows executables.

Download the [MSYS2 installer][msys2] and install the MSYS2
environment locally. For the sake of the example this document assumes
that you installed it in the default location:

    C:\msys64

MSYS2 has many different [environments][subsys], among which:
  - The MSYS environment, which contains all the base UNIX-like
    tools under /usr and is special in that it is always active.
  - The UCRT64 environment, which builds on top of the MSYS environment
    and provides only Windows-native binaries under /ucrt64/bin

Ngdevkit is built for Windows with no MSYS2/Unix dependencies in
mind, so it targets the UCRT64. In order to compile it successfully,
you must be running a shell under the UCRT64 environment. You can
start the shell by running "MSYS2 UCRT64" from the Start menu.
Alternatively, you can also start the shell from `cmd.exe` or from
PowerShell with:

    set MSYSTEM=UCRT64
    C:\msys64\usr\bin\bash.exe -l

Once you are in a MSYS2 shell, make sure your MSYS2 installation
is up-to-date and pacboy is available:

    pacman -Syuu
    pacman -S pactoys
    pacboy -S msys2-w32api-runtime
    exit

Package `msys2-w32api-runtime` sometimes requires you to restart your
shell after installation/upgrade, so it's easier to do it all the
time and restart a new one from there.

## Compiling the devkit

In a new shell running in the UCRT64 environment, first install all the
ngdevkit dependencies:

    pacboy -S msys2-w32api-runtime windows-default-manifest
    pacboy -S msys2-runtime-devel msys2-w32api-headers
    pacboy -S autoconf autoconf-archive automake pkgconf make tar zip unzip
    pacboy -S git flex bison expat gettext ncurses-devel zlib-devel
    pacboy -S gmp-devel isl-devel mpc-devel mpfr-devel texinfo
    pacboy -S python:u python-pygame:u toolchain:u zlib:u SDL2:u glew:u boost:u
    # dependencies for the example ROMs
    pacboy -S rsync sox:u imagemagick:u

You can now compile the entire devkit. The latest ngdevkit's autoconf
script should detect the location of all dependencies (python,
pygame...) automatically, as long as you're running it in a UCRT64
environment as required.

    autoreconf -iv
    ./configure --prefix=$PWD/local
    make
    make install


The most tedious part is over! You can now configure your environment
to add the built binaries to your `PATH` and start experimenting
with the devkit and build the example ROMs:

    eval $(make shellinit)
    cd examples
    # build the example ROMs (make sure you're still in a UCRT64 shell)
    ./configure
    make

Look at [the main README](README.md) file for more details on
how to run the examples and the debugger.


[msys2]: https://www.msys2.org
[examples]: https://github.com/dciabrin/ngdevkit-examples
[pywin]: https://www.python.org/downloads/windows
[pygame]: https://www.pygame.org
[subsys]: https://www.msys2.org/docs/environments
