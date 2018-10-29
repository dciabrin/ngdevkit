AC_INIT([libemudbg], [0.2])
AC_CANONICAL_TARGET
AM_INIT_AUTOMAKE([-Wall])
PKG_INSTALLDIR
AC_PROG_CC
AM_PROG_AR
AC_PROG_RANLIB

case $target_os in
    *mingw*)
    EMUDBG_PKGLIB="$EMUDBG_PKGLIB -lws2_32"
    ;;
esac

dnl AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([
 emudbg.pc
 Makefile
 src/Makefile
])
AC_SUBST(EMUDBG_PKGLIB)
AC_OUTPUT
