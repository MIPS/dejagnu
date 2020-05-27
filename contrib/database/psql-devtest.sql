-- Copyright (C) 2020 Free Software Foundation, Inc.

-- This file is part of DejaGnu.

-- DejaGnu is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.

--
-- Developer unit tests for DejaGnu PostgreSQL database stored functions.
--
--  These are not exhaustive, but are only a simple sanity check.
--

--
-- Run with:  psql -At
-- Extract expected output with:  sed -ne '/^.*-- *EXPECT */{s///;p}'
--

SELECT dejagnu.set_tag_from_name('foo/bar');		-- EXPECT foo.bar
SELECT dejagnu.set_tag_from_name('foo/bar/b++');	-- EXPECT foo.bar.b__
SELECT dejagnu.set_tag_from_name('foo/t12345.c');	-- EXPECT foo.t12345_c

SELECT dejagnu.intern_set_by_name('foo/bar');		-- EXPECT 1
SELECT dejagnu.intern_set_by_name('foo/bar/b++');	-- EXPECT 2
SELECT dejagnu.intern_set_by_name('foo/bar');		-- EXPECT 1
SELECT dejagnu.intern_set_by_name('foo/t12345.c');	-- EXPECT 3

SELECT * FROM dejagnu.sets;
-- EXPECT 1|foo/bar|foo.bar
-- EXPECT 2|foo/bar/b++|foo.bar.b__
-- EXPECT 3|foo/t12345.c|foo.t12345_c

-- EOF
