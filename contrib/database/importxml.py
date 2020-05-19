#!/usr/bin/python3

# importxml.py -- import a .sum file into Postgresql
#
# Copyright (C) 2020 Free Software Foundation, Inc.
#
# This file is part of DejaGnu.
#
# DejaGnu is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

# This script takes a compressed or uncompressed sum file from a
# DejaGnu test run. It then extracts the relevant information about
# the build and writes that to the dejagnu.testruns control
# table.


import os
import sys
import getopt
import pdb
import re
from lxml import etree
from lxml.etree import tostring
import psycopg2


infile = "ld.xml"
dbname = "dejagnu"

try:
    connect = " dbname=" + dbname
    dbshell = psycopg2.connect(connect)
    if dbshell.closed == 0:
        dbshell.autocommit = True
        print("Opened connection to %r %r" % (dbname, dbshell))
        
        dbcursor = dbshell.cursor()
        if dbcursor.closed == 0:
            print("Opened cursor in %r %r" % (dbname, dbcursor))
            
except Exception as e:
    print("Couldn't connect to database: %r" % e)
    
# Get the last testrun number
testrun = None
query = "SELECT testrun FROM testruns ORDER BY testruns DESC LIMIT 1;"
try:
    dbcursor.execute(query)
except Exception as e:
    if e.pgcode != None:
        print("ERROR: Query failed to fetch! %r" % e.pgerror)
        print("ERROR: Query that failed: %r" % query)
        quit()
testrun = dbcursor.fetchone()
if testrun is None:
    testrun = "1"
else:
    testrun = str(int(testrun) + 1)

#
# Parse the XML file from the test run
#
doc = etree.parse(infile)
for docit in doc.getiterator():
    print("TAG: %r" % docit.tag)
    if docit.tag == 'test':
        for elit in docit.getiterator():
            print("\tTAG: %r" % elit.tag)

#
# Read manifest file
#
manifest="/home/rob/projects/gnu/abe.git/dejagnu/builds/x86_64-unknown-linux-gnu/x86_64-unknown-linux-gnu/gcc-linaro-8.3.0~releases-gcc-8.3.0@4c44b708-20200518-linux-manifest.txt"
file = open(manifest, 'r')
line = "#"
manifest = dict()
data = dict()
tool = None
oldtool = None
while len(line) > 0:
    line = file.readline().rstrip()
    if len(line) == 0 or line == '\n' or line[0] == '#' or line[:2] == ' #' or line[0] == '\n':
        line = file.readline()
        continue
    nodes = line.split('=')
    if len(nodes) < 2:
        nodes = line.split(':')
    key = nodes[0]
    if len(nodes)<=1:
        break
    else:
        value = nodes[1]

    patterns = ("^host:",  "^host_gcc:", ".*_branch", ".*_filespec", ".*_revision", ".*_md5sum")
    for pat in patterns:
        m = re.match(pat, key, re.IGNORECASE)
        if m is not None:
            tool = key.split('_')[0]
            entry = key.split('_')[1]
            # print("FIXME: %r, %r, %r" % (tool, entry, value))
            data[entry] = value
    if tool is not None and oldtool != tool:
        oldtool = tool
        manifest[tool] = data
        data = dict()

for tool,entry in manifest.items():
    if len(entry) <= 0:
        continue
    print("FIXME: %r" % entry)
    # If filespec is present, it's from a tarball
    if 'filespec' in entry and 'md5sum' in entry:
        query = """INSERT INTO manifest(testrun, tool, filespec, md5sum) VALUES(%r, %r, %r, %r);"""% (testrun, tool, manifest[tool]['filespec'], manifest[tool]['md5sum'])
    elif 'branch' in entry and 'revision' in entry:
        query = """INSERT INTO manifest(testrun, tool, branch, revision) VALUES(%r, %r, %r, %r);""" % (testrun,  tool, manifest[tool]['branch'], manifest[tool]['revision'])

    print(query)
    try:
        dbcursor.execute(query)
    except Exception as e:
        if e.pgcode != None:
            print("ERROR: Query failed to fetch! %r" % e.pgerror)
            print("ERROR: Query that failed: %r" % query)
    #line = dbcursor.fetchone()
