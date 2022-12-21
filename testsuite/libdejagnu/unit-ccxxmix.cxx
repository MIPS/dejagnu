// Exerciser for Dejagnu C/C++ unit test support library mixed usage
//
// Copyright (C) 2022 Free Software Foundation, Inc.
//
// This file is part of DejaGnu.
//
// DejaGnu is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// (at your option) any later version.
//
// DejaGnu is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with DejaGnu; if not, write to the Free Software Foundation,
// Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1301, USA.
//
// This file was written by Jacob Bachmeyer.

// This version of the program allows verifying that the shared counters
// between the C API and the C++ API really are shared as documented.

#include <stdio.h>
#include <string.h>

#include <cstring>
#include <iostream>

#include "dejagnu.h"

TestState DGT;

int
main(int argc, char ** argv)
{
  if (argc < 2) {
    std::cerr <<"usage: " <<argv[0] <<" <test name>..."<<std::endl
	      <<"see source for details" <<std::endl;
    return 2;
  }

  for (int i = 1; i < argc; i++ ) {
    if (i & 1) { // alternate with each test on the command line
      if (!std::strcmp("pass", argv[i]))              DGT.pass("test");
      else if (!std::strcmp("xpass", argv[i]))        DGT.xpass("test");
      else if (!std::strcmp("fail", argv[i]))         DGT.fail("test");
      else if (!std::strcmp("xfail", argv[i]))        DGT.xfail("test");
      else if (!std::strcmp("untested", argv[i]))     DGT.untested("test");
      else if (!std::strcmp("unresolved", argv[i]))   DGT.unresolved("test");
      else if (!std::strcmp("unsupported", argv[i]))  DGT.unsupported("test");
      else if (!std::strcmp("note", argv[i]))         DGT.note("test");
      else if (!std::strcmp("error", argv[i]))	      DGT.error("test");
      else if (!std::strcmp("warning", argv[i]))      DGT.warning("test");
      else {
	std::cerr <<argv[0] <<": unknown test `" <<argv[i] <<"'" <<std::endl;
	return 2;
      }
    } else { // use C API for every other test
      if (!strcmp("pass", argv[i]))                   pass("test");
      else if (!strcmp("xpass", argv[i]))             xpass("test");
      else if (!strcmp("fail", argv[i]))              fail("test");
      else if (!strcmp("xfail", argv[i]))             xfail("test");
      else if (!strcmp("untested", argv[i]))          untested("test");
      else if (!strcmp("unresolved", argv[i]))        unresolved("test");
      else if (!strcmp("unsupported", argv[i]))       unsupported("test");
      else if (!strcmp("note", argv[i]))              note("test");
      else if (!strcmp("error", argv[i]))             DG_error("test");
      else if (!strcmp("warning", argv[i]))           DG_warning("test");
      else {
	fprintf(stderr, "%s: unknown test `%s'\n", argv[0], argv[i]);
	return 2;
      }
    }
  }

  return 0;
}

// EOF
