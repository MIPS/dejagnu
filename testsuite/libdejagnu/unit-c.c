/* Exerciser for DejaGnu C unit test support library
 *
 * Copyright (C) 2022 Free Software Foundation, Inc.
 *
 * This file is part of DejaGnu.
 *
 * DejaGnu is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * DejaGnu is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with DejaGnu; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1301, USA.
 *
 * This file was written by Jacob Bachmeyer.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "dejagnu.h"

int
main(int argc, char ** argv)
{
  int i;

  if (argc < 2) {
    fprintf(stderr,
	    "usage: %s <test name>...\n  see source for details\n", argv[0]);
    return 2;
  }

  for (i = 1; i < argc; i++) {
    if (!strcmp("pass", argv[i]))		pass("test");
    else if (!strcmp("xpass", argv[i]))		xpass("test");
    else if (!strcmp("fail", argv[i]))		fail("test");
    else if (!strcmp("xfail", argv[i]))		xfail("test");
    else if (!strcmp("untested", argv[i]))	untested("test");
    else if (!strcmp("unresolved", argv[i]))	unresolved("test");
    else if (!strcmp("unsupported", argv[i]))	unsupported("test");
    else if (!strcmp("note", argv[i]))		note("test");
    else {
      fprintf(stderr, "%s: unknown test `%s'\n", argv[0], argv[i]);
      return 2;
    }
  }

  totals();

  return 0;
}

/* EOF */
