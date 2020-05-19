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

DROP TABLE IF EXISTS tests;
CREATE TABLE tests (
  testrun integer NOT NULL DEFAULT '12345',
  tool varchar(128) NOT NULL,
  result public.status,
  name varchar(128) NOT NULL,
  output varchar(256),
  input varchar(128),
  prmsid integer
);

DROP TABLE IF EXISTS testruns;
CREATE TABLE testruns (
  date timestamp NOT NULL,
  testrun integer NOT NULL,
  target varchar(72) NOT NULL,
  build varchar(72) NOT NULL,
  UNIQUE(testrun)
);

DROP TABLE IF EXISTS manifest;
CREATE TABLE manifest (
  testrun integer NOT NULL,
  tool varchar(72) NOT NULL,
  branch varchar(72),
  filespec varchar(72),
  md5sum varchar(72),
  revision varchar(72),
  host varchar(72),
  host_gcc varchar(72)
);
