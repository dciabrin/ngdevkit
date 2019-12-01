AC_INIT([ngdevkit], [0.2])
PKG_INSTALLDIR

AC_PATH_PROGS([python], [python3 python], [no])
if test x"$python" = x"no"; then
  AC_MSG_ERROR([no python detected.])
fi
AC_MSG_CHECKING([whether detected python is at least python3])
[pyver=`$python -c 'import sys; print(sys.version_info[0])'`]
if test $pyver -ge 3; then
  AC_MSG_RESULT([yes])
else
  AC_MSG_ERROR([python major version too old (detected: $pyver, required: 3)])
fi

AC_PATH_PROGS([install], [install])

AC_ARG_ENABLE([external-toolchain],
	      AS_HELP_STRING([--enable-external-toolchain], [Build the toolchain (compilers, assembler, linker, debugger)]),
	      AS_IF([test "x$enable_external_toolchain" = xyes], [EXTERNAL_TOOLCHAIN="yes"], [EXTERNAL_TOOLCHAIN="no"]),
              [EXTERNAL_TOOLCHAIN="no"])
AC_SUBST([EXTERNAL_TOOLCHAIN])

AC_ARG_ENABLE([external-emudbg],
              AS_HELP_STRING([--enable-external--emudbg], [Build the source-level debugging API for GnGeo]),
	      AS_IF([test "x$enable_external_emudbg" = xyes], [EXTERNAL_EMUDBG="yes"], [EXTERNAL_EMUDBG="no"]),
              [EXTERNAL_EMUDBG="no"])
AC_SUBST([EXTERNAL_EMUDBG])

AC_ARG_ENABLE([external-gngeo],
              AS_HELP_STRING([--enable-external-gngeo], [Build the GnGeo emulator, customized for ngdevkit]),
	      AS_IF([test "x$enable_external_gngeo" = xyes], [EXTERNAL_GNGEO="yes"], [EXTERNAL_GNGEO="no"]),
              [EXTERNAL_GNGEO="no"])
AC_SUBST([EXTERNAL_GNGEO])

AC_ARG_ENABLE([examples],
              AS_HELP_STRING([--enable-examples], [Clone and build the ngdevkit-examples repository]),
              AS_IF([test "x$enable_examples" = xyes], [EXAMPLES="yes"], [EXAMPLES="no"]),
              [EXAMPLES="yes"])
AC_SUBST([EXAMPLES])

dnl
dnl MinGW-specific options
dnl
AC_ARG_ENABLE([mingw],
	      AS_HELP_STRING([--enable-mingw], [Build Win10-native versions of emudbg and gngeo]),
	      AS_IF([test "x$enable_mingw" = xyes], [ENABLE_MINGW="yes"], [ENABLE_MINGW="no"]),
              [ENABLE_MINGW="no"])
AC_SUBST([EXTERNAL_MINGW])

AC_ARG_WITH([sdl2],
            AS_HELP_STRING([--with-sdl2=path], [Absolute path to file SDL2.dll]))

AC_ARG_WITH([glew],
            AS_HELP_STRING([--with-glew=path], [Absolute path to GLEW binary development distribution]))


dnl if ngdevkit-toolkit is already installed system-wide, use it
if test x"$EXTERNAL_TOOLCHAIN" = x"yes"; then
AC_PATH_PROG([nggcc], [m68k-neogeo-elf-gcc], [no])
AS_IF([test x"$nggcc" = x"no"], [AC_MSG_ERROR([m68k-neogeo-elf-gcc not found in path.])])
AC_PATH_PROG([ngas], [m68k-neogeo-elf-as], [no])
AS_IF([test x"$ngas" = x"no"], [AC_MSG_ERROR([m68k-neogeo-elf-as not found in path.])])
AC_PATH_PROG([ngld], [m68k-neogeo-elf-ld], [no])
AS_IF([test x"$ngld" = x"no"], [AC_MSG_ERROR([m68k-neogeo-elf-ld not found in path.])])
AC_PATH_PROG([ngar], [m68k-neogeo-elf-ar], [no])
AS_IF([test x"$ngar" = x"no"], [AC_MSG_ERROR([m68k-neogeo-elf-ar not found in path.])])
AC_PATH_PROG([ngranlib], [m68k-neogeo-elf-ranlib], [no])
AS_IF([test x"$nranlib" = x"no"], [AC_MSG_ERROR([m68k-neogeo-elf-ranlib not found in path.])])
AC_PATH_PROG([ngobjcopy], [m68k-neogeo-elf-objcopy], [no])
AS_IF([test x"ngobjcopy" = x"no"], [AC_MSG_ERROR([m68k-neogeo-elf-objcopy not found in path.])])
AC_PATH_PROG([ngsdcc], [z80-neogeo-ihx-sdcc], [no])
AS_IF([test x"ngsdcc" = x"no"], [AC_MSG_ERROR([z80-neogeo-ihx-sdcc not found in path.])])
AC_PATH_PROG([ngsdas], [z80-neogeo-ihx-sdasz80], [no])
AS_IF([test x"ngsdas" = x"no"], [AC_MSG_ERROR([z80-neogeo-ihx-sdas not found in path.])])
AC_PATH_PROG([ngsdld], [z80-neogeo-ihx-sdldz80], [no])
AS_IF([test x"ngsdld" = x"no"], [AC_MSG_ERROR([z80-neogeo-ihx-sdld not found in path.])])
AC_PATH_PROG([ngsdar], [z80-neogeo-ihx-sdar], [no])
AS_IF([test x"ngsdar" = x"no"], [AC_MSG_ERROR([z80-neogeo-ihx-sdar not found in path.])])
AC_PATH_PROG([ngsdranlib], [z80-neogeo-ihx-sdranlib], [no])
AS_IF([test x"ngsdranlib" = x"no"], [AC_MSG_ERROR([z80-neogeo-ihx-sdranlib not found in path.])])
AC_PATH_PROG([ngsdobjcopy], [z80-neogeo-ihx-sdobjcopy], [no])
AS_IF([test x"ngsdobjcopy" = x"no"], [AC_MSG_ERROR([z80-neogeo-ihx-sdobjcopy not found in path.])])
else
dnl Otherwise we'll build it
nggcc=$prefix/bin/m68k-neogeo-elf-gcc
ngas=$prefix/bin/m68k-neogeo-elf-as
ngld=$prefix/bin/m68k-neogeo-elf-ld
ngar=$prefix/bin/m68k-neogeo-elf-ar
ngranlib=$prefix/bin/m68k-neogeo-elf-ranlib
ngobjcopy=$prefix/bin/m68k-neogeo-elf-objcopy
ngsdcc=$prefix/bin/z80-neogeo-ihx-sdcc
ngsdas=$prefix/bin/z80-neogeo-ihx-sdasz80
ngsdld=$prefix/bin/z80-neogeo-ihx-sdldz80
ngsdar=$prefix/bin/z80-neogeo-ihx-sdar
ngsdranlib=$prefix/bin/z80-neogeo-ihx-sdranlib
ngsdobjcopy=$prefix/bin/z80-neogeo-ihx-sdobjcopy
fi



AC_PATH_PROG([git], [git])
AC_PATH_PROG([zip], [zip])

if test x"$ENABLE_MINGW" = x"yes"; then
  AC_PATH_PROG([mingwgcc], [`uname -m`-w64-mingw32-gcc], [no])
  AS_IF([test x"$mingwgcc" = x"no"], [AC_MSG_ERROR([MinGW gcc not found in path.])])

  AC_MSG_CHECKING([for zlib1.dll in MinGW distribution])
  ZLIB1_DLL=`$mingwgcc -print-file-name=zlib1.dll`
  if test -f "$ZLIB1_DLL"; then
    AC_MSG_RESULT([$ZLIB1_DLL])
  else
    AC_MSG_ERROR([Could not find zlib1.dll on disk])
  fi

  AC_MSG_CHECKING([for SDL2])
  if test -n "$with_sdl2" && test x"$with_sdl2" != x"no" && test -f "$with_sdl2"; then
    AC_MSG_RESULT([$with_sdl2])
    SDL2_DLL=$with_sdl2
  else
    AC_MSG_ERROR(['$with_sdl2' is not a valid file on disk])
  fi

  AC_MSG_CHECKING([for GLEW binary development distribution])
  if test -n "$with_glew" && test x"$with_glew" != x"no" && test -d "$with_glew"; then
    if test x"`uname -m`" = x"x86_64"; then
      glew_dir=${with_glew}/bin/Release/x64
    else
      glew_dir=${with_glew}/bin/Release/Win32
    fi
    GLEW_FLAGS=--with-glew=$with_glew
    GLEW_DLL=$glew_dir/glew32.dll
    AC_MSG_RESULT([$with_glew])
  else
    AC_MSG_RESULT([no])
  fi

  if test x"$EXTERNAL_GNGEO" != x"yes"; then
    AC_MSG_CHECKING([for GnGeo installation directory])
    if test -z "$GNGEO_INSTALL_PATH"; then
      GNGEO_INSTALL_PATH="$prefix/ngdevkit-gngeo"
    fi
    AC_MSG_RESULT([$GNGEO_INSTALL_PATH])
  fi

  EMUDBG_BUILD_FLAGS="--host=x86_64-w64-mingw32"
  GNGEO_BUILD_FLAGS="--prefix=$GNGEO_INSTALL_PATH --enable-mingw --host=x86_64-w64-mingw32 $GLEW_FLAGS"
else
  GNGEO_BUILD_FLAGS="--prefix=$prefix"
fi

AC_SUBST([ENABLE_MINGW])
AC_SUBST([ZLIB1_DLL])
AC_SUBST([SDL2_DLL])
AC_SUBST([GLEW_FLAGS])
AC_SUBST([GLEW_DLL])
AC_SUBST([EMUDBG_BUILD_FLAGS])
AC_SUBST([GNGEO_BUILD_FLAGS])
AC_SUBST([GNGEO_INSTALL_PATH])


dnl AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([
 ngdevkit.pc
 Makefile
 Makefile.config
 runtime/Makefile
 include/Makefile
 nullbios/Makefile
 nullsound/Makefile
 tools/Makefile
])
AC_OUTPUT
