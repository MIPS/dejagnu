-- Copyright (C) 2016-2019, 2020 Free Software Foundation, Inc.

-- This file is part of DejaGnu.

-- DejaGnu is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.

--
-- Table structure for table `test`
--
CREATE TYPE public.status AS ENUM (
       'PASS',
       'FAIL',
       'XPASS',
       'XFAIL',
       'UNTESTED',
       'UNRESOLVED',
       'UNSUPPORTED'
);

DROP TABLE IF EXISTS test;
CREATE TABLE test (
  testrun integer NOT NULL DEFAULT '12345',
  input varchar(128) NOT NULL,
  output varchar(256) NOT NULL,
  result public.status,
  name varchar(128) NOT NULL,
  prmsid integer NOT NULL
);

DROP TABLE IF EXISTS testruns;
CREATE TABLE testruns (
  tool varchar(72) NOT NULL,
  date timestamp NOT NULL,
  version varchar(72) NOT NULL,
  branch varchar(72) NOT NULL,
  testrun integer NOT NULL,
  arch varchar(72) NOT NULL,
  build_machine varchar(72) NOT NULL
);


