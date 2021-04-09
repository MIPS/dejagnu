dnl Process this file with autoconf to produce a configure script.

dnl Copyright (C) 1992-2019, 2020 Free Software Foundation, Inc.
dnl
dnl This file is part of DejaGnu.
dnl
dnl DejaGnu is free software; you can redistribute it and/or modify it
dnl under the terms of the GNU General Public License as published by
dnl the Free Software Foundation; either version 3 of the License, or
dnl (at your option) any later version.
dnl
dnl DejaGnu is distributed in the hope that it will be useful, but
dnl WITHOUT ANY WARRANTY; without even the implied warranty of
dnl MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
dnl General Public License for more details.
dnl
dnl You should have received a copy of the GNU General Public License
dnl along with DejaGnu; if not, write to the Free Software Foundation,
dnl Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1301, USA.

AC_PREREQ([2.69])
AC_INIT([GNU DejaGnu],[1.6.3-rc2],[bug-dejagnu@gnu.org])
AM_INIT_AUTOMAKE([1.14 subdir-objects])
AM_MAINTAINER_MODE
AC_PROG_MAKE_SET

AC_PROG_AWK
AC_PROG_CC
AC_PROG_CXX
AC_PROG_INSTALL
AC_EXEEXT

if test -z "$AWK"; then
  AC_MSG_ERROR([AWK not installed])
fi

# Provide an empty global site file (/dev/null) as default.
if test x"$DEJAGNU" = x
then
  DEJAGNU="/dev/null"
fi
AC_SUBST(DEJAGNU)
# Makefile.am arranges for DEJAGNU to be exported in the environment.

# Patch interpreter lines in config.* scripts to reference CONFIG_SHELL.
# Normally configure ensures that these scripts are run using CONFIG_SHELL
# and their interpreter lines are ignored, but DejaGnu also installs
# config.guess and the framework invokes it at runtime.
if test x"$SHELL" != x/bin/sh
then
  AC_CONFIG_COMMANDS([scriptpatch],[
    for file in config.guess config.sub
    do
      f=${ac_srcdir}/${file}
      sed -e '1s,^@%:@!.*$,@%:@! '"${SHELL}", $f > ${f}.new
      if test `awk 'END {print NR}' $f` != `awk 'END {print NR}' ${f}.new`
      then
	AC_MSG_ERROR([patching script for local shell changed line count!])
      fi
      mv -f ${f}.new $f
    done
], [SHELL=$SHELL])
fi

AC_CONFIG_FILES([Makefile])
AC_OUTPUT
