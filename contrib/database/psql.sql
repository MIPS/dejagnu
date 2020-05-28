-- Copyright (C) 2016-2019, 2020 Free Software Foundation, Inc.

-- This file is part of DejaGnu.

-- DejaGnu is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.

--
-- Table structure for DejaGnu tables
--
BEGIN;

DROP SCHEMA IF EXISTS dejagnu CASCADE;
CREATE SCHEMA dejagnu;

CREATE TYPE dejagnu.result AS ENUM (
       'PASS',   'FAIL',
       'XPASS', 'XFAIL',
       'KPASS', 'KFAIL',
       'UNTESTED', 'UNRESOLVED', 'UNSUPPORTED'
);

CREATE TABLE dejagnu.runs (
  run bigserial PRIMARY KEY,
  start timestamp with time zone NOT NULL,
  target text NOT NULL,
  host text NOT NULL,
  build text NOT NULL,
  CONSTRAINT "target looks like an arch tuple"
    CHECK(target LIKE '%-%'),
  CONSTRAINT "host looks like an arch tuple"
    CHECK(host LIKE '%-%'),
  CONSTRAINT "build looks like an arch tuple"
    CHECK(build LIKE '%-%')
);

CREATE TABLE dejagnu.manifests (
  manifest bigserial PRIMARY KEY,
  sha1sum text NOT NULL UNIQUE,
  CONSTRAINT "valid hex sha1sum"
    CHECK(lower(sha1sum) SIMILAR TO '[0-9a-f]{40}')
);

CREATE TABLE dejagnu.manifest_packages (
  manifest bigint NOT NULL
    REFERENCES dejagnu.manifests ON DELETE CASCADE,
  package text NOT NULL,
  src_url text,
  filespec text,
  branch text,
  md5sum text,
  revision text,
  configure_options text,
  PRIMARY KEY (manifest, package),
  CONSTRAINT "md5sum xor revision"
    CHECK(((md5sum IS NOT NULL) AND (revision IS NULL))
	  OR ((md5sum IS NULL)  AND (revision IS NOT NULL))),
  CONSTRAINT "valid hex md5sum"
    CHECK((md5sum IS NULL) OR (lower(md5sum) SIMILAR TO '[0-9a-f]{32}'))
);

CREATE TABLE dejagnu.manifest_runs (
  manifest bigint NOT NULL
    REFERENCES dejagnu.manifests ON DELETE RESTRICT,
  run bigint NOT NULL
    REFERENCES dejagnu.runs ON DELETE RESTRICT,
  PRIMARY KEY (manifest, run)
);

CREATE TABLE dejagnu.sets (
  set serial PRIMARY KEY,
  name text NOT NULL UNIQUE,
  tag ltree NOT NULL
);

CREATE FUNCTION dejagnu.set_tag_from_name
	(name text, OUT tag dejagnu.sets.tag%TYPE)
  AS $$
    BEGIN
      tag := regexp_replace(regexp_replace(name, '[^a-zA-Z0-9/]', '_', 'g'),
						 '/', '.', 'g');
    END;
  $$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE FUNCTION dejagnu.intern_set_by_name
	(set_name text, OUT set_id dejagnu.sets.set%TYPE)
  AS $$
    BEGIN
      SELECT set INTO set_id FROM dejagnu.sets WHERE name = set_name;
      IF NOT FOUND THEN
	INSERT
	  INTO dejagnu.sets (name, tag)
	  VALUES (set_name, dejagnu.set_tag_from_name(set_name))
	  RETURNING set INTO STRICT set_id;
      END IF;
    END;
  $$ LANGUAGE plpgsql STRICT VOLATILE;

CREATE TABLE dejagnu.results (
  run bigint NOT NULL
    REFERENCES dejagnu.runs ON DELETE CASCADE,
  set integer NOT NULL
    REFERENCES dejagnu.sets ON DELETE RESTRICT,
  result dejagnu.result NOT NULL,
  name text NOT NULL,
  output text,
  input text,
  prmsid text
);
CREATE INDEX results_run_result_idx
  ON dejagnu.results (run, result);
CREATE INDEX results_run_set_result_idx
  ON dejagnu.results (run, set, result);

COMMIT;
