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
