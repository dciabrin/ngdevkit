AC_INIT([ngdevkit], [0.3])
PKG_INSTALLDIR

AC_ARG_WITH([python],
            AS_HELP_STRING([--with-python=path], [Absolute path to the python 3 binary]))

if test -n "$with_python"; then
  python="$with_python"
  AC_SUBST([python])
else
  AC_PATH_PROGS([python], [python3 python], [no])
  if test x"$python" = x"no"; then
    AC_MSG_ERROR([no python detected.])
  fi
fi
AC_MSG_CHECKING([whether python is at least python3])
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

AC_ARG_ENABLE([msys2],
	      AS_HELP_STRING([--enable-msys2], [Build for MSYS2, with Win10-native gngeo]),
	      AS_IF([test "x$enable_msys2" = xyes], [ENABLE_MSYS2="yes"], [ENABLE_MSYS2="no"]),
              [ENABLE_MSYS2=""])

# dnl if not configured explicitly, auto-detect msys2 env
if test x"$ENABLE_MSYS2" = x""; then
   if test -n "$MSYSTEM" -a -n "$MSYSTEM_CARCH" -a -n "$MSYSTEM_CHOST" -a -n "$MSYSTEM_PREFIX"; then
      AC_MSG_CHECKING([for the current MSYS2 environment/subsystem])
      AC_MSG_RESULT([$MSYSTEM])
      ENABLE_MSYS2=yes
   else
      ENABLE_MSYS2=no
   fi
fi

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

dnl customize pkg-config in case we don't install in gcc's prefix
gcc_libpath=$(dirname $($nggcc --print-libgcc-file-name))
gcc_rel_libpath=$(echo ${gcc_libpath} | sed -n 's%^.*/\(gcc/.*\)%\1%p')
gcc_prefix=$(echo ${gcc_libpath} | sed -n 's%^\(.*\)/m68k-neogeo-elf/lib.*%\1%p')
if test x"${gcc_prefix}" != x"${prefix}"; then
NGDK_GCC_SEARCH_PATH="-B\${libdir} -B\${libdir}/${gcc_rel_libpath}"
else
NGDK_GCC_SEARCH_PATH=""
fi

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

EXTRA_BUILD_CMD_TOOLCHAIN=true
EXTRA_BUILD_FLAGS_TOOLCHAIN=
EXTRA_BUILD_CMD=true

if test x"$ENABLE_MSYS2" = x"yes"; then
  AC_PATH_PROG([msys2gcc], [$MSYSTEM_CHOST-gcc], [no])
  AS_IF([test x"msys2gcc" = x"no"], [AC_MSG_ERROR([$MSYSTEM_CHOST-gcc not found in path.])])
  PKG_CHECK_MODULES([zlib],[zlib])
  ZLIB1_DLL=$MSYSTEM_PREFIX/bin/zlib1.dll
  PKG_CHECK_MODULES([SDL2],[SDL2])
  SDL2_DLL=$MSYSTEM_PREFIX/bin/SDL2.dll

  AC_MSG_CHECKING([for GLEW])
  if test -f "$MSYSTEM_PREFIX/bin/glew32.dll"; then
    GLEW_FLAGS=--with-glew
    GLEW_DLL=$MSYSTEM_PREFIX/bin/glew32.dll
    AC_MSG_RESULT([yes])
  else
    AC_MSG_RESULT([no])
  fi

  if test x"$EXTERNAL_GNGEO" != x"yes"; then
    AC_MSG_CHECKING([for GnGeo installation directory])
    if test -z "$GNGEO_INSTALL_PATH"; then
      GNGEO_INSTALL_PATH="$prefix"
    fi
    AC_MSG_RESULT([$GNGEO_INSTALL_PATH])
  fi

  EMUDBG_BUILD_FLAGS="--build=x86_64-w64-mingw32 --host=x86_64-w64-mingw32 --target=x86_64-w64-mingw32"
  GNGEO_BUILD_FLAGS="--prefix=$GNGEO_INSTALL_PATH --enable-msys2 $GLEW_FLAGS"
  dnl This is necessary for gngeo to not convert path
  EXTRA_BUILD_CMD='export MSYS2_ARG_CONV_EXCL="-DDATA_DIRECTORY="'
  dnl building the toolchain only works with MSYS sed
  EXTRA_BUILD_CMD_TOOLCHAIN='mkdir -p $$(BUILD)/sed-msys2;cp /usr/bin/sed.exe $$(BUILD)/sed-msys2; export PATH=$$(BUILD)/sed-msys2:$$$$PATH'
  EXTRA_BUILD_FLAGS_TOOLCHAIN='--build=x86_64-w64-mingw32 --host=x86_64-w64-mingw32'
else
  GNGEO_BUILD_FLAGS="--prefix=$prefix"
fi

AC_SUBST([EXTRA_BUILD_CMD_TOOLCHAIN])
AC_SUBST([EXTRA_BUILD_FLAGS_TOOLCHAIN])
AC_SUBST([EXTRA_BUILD_CMD])

AC_SUBST([ENABLE_MSYS2])
AC_SUBST([ZLIB1_DLL])
AC_SUBST([SDL2_DLL])
AC_SUBST([GLEW_DLL])
AC_SUBST([EMUDBG_BUILD_FLAGS])
AC_SUBST([GNGEO_BUILD_FLAGS])
AC_SUBST([GNGEO_INSTALL_PATH])
AC_SUBST([NGDK_GCC_SEARCH_PATH])


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

if test x"$ENABLE_MSYS2" = x"yes"; then
    # dnl recap warning in the summary
    if echo $MSYSTEM | grep -q -w -v -e UCRT64; then
        AC_MSG_WARN([Unsupported environment ($MSYSTEM). You should run `configure` in the UCRT64 environment])
    fi
fi
