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


#
# This script imports the XML output files from DejaGnu into a
# Postgresql database for easier analysis. As it parses
# the manifest file produced by a toolchain build when
# when using ABE, building thw toolchain requires ABE.
# 
import os
import sys
import getopt
import pdb
import re
from lxml import etree
from lxml.etree import tostring
import psycopg2
from datetime import datetime
from sys import argv
# from tqdm import tqdm
# from progress.bar import Bar, PixelBar
from progress.spinner import PixelSpinner


def usage(argv):
    print(argv[0] + ": options: xmlfile xmlfile xmlfile, etc...")
    print("""
\t--help(-h)   Help
\t--database(-d)  database (default "dejagnu")
\t--manifest(-m)  Manifest file name
\t--testrun(-m)   Testrun number (optional)
        """)
    quit()

# Default values
dbname = "dejagnu"
infiles = ""
manifest = None
testrun = None

try:
    (opts, vals) = getopt.getopt(argv[1:], "h,m:,d:,t:", ["help", "manifest", "database", "testrun"])
    for (opt, val) in opts:
        if opt == '--help' or opt == '-h':
            usage(argv)
        elif opt == "--testrun" or opt == '-t':
            testrun = val
        elif opt == "--database" or opt == '-d':
            dbname = val
        elif opt == "--manifest" or opt == '-m':
            manifest = val
        else:
            infiles += val
except getopt.GetoptError as e:
    logging.error('%r' % e)
    usage(argv)
    quit()

infiles = vals
if not infiles or not manifest:
    usage(argv)

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
if not testrun:
    query = "SELECT testrun FROM testruns ORDER BY testruns DESC LIMIT 1;"
    try:
        dbcursor.execute(query)
    except Exception as e:
        if e.pgcode != None:
            print("ERROR: Query failed to fetch! %r" % e.pgerror)
            print("ERROR: Query that failed: %r" % query)
            quit()
    tmp = dbcursor.fetchone()
    if tmp is None:
        testrun = "1"
    else:
        testrun = str(int(tmp[0]) + 1)

#
# Read manifest file
#
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

    patterns = ("^target$", "^host$",  "^host_gcc$", ".*_branch", ".*_filespec", ".*_revision", ".*_md5sum")
    for pat in patterns:
        m = re.match(pat, key, re.IGNORECASE)
        if m is not None:
            tool = key.split('_')[0]
            if tool == 'target':
                entry = line.split('=')[1]
            elif key == 'host' or key == 'host_gcc':
                entry = line.split(':')[1]
            else:
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
    # print("FIXME: %r" % entry)
    # If filespec is present, it's from a tarball
    if 'filespec' in entry and 'md5sum' in entry:
        query = """INSERT INTO manifest(testrun, tool, filespec, md5sum) VALUES(%r, %r, %r, %r);"""% (testrun, tool, manifest[tool]['filespec'], manifest[tool]['md5sum'])
    elif 'branch' in entry and 'revision' in entry:
        query = """INSERT INTO manifest(testrun, tool, branch, revision) VALUES(%r, %r, %r, %r);""" % (testrun,  tool, manifest[tool]['branch'], manifest[tool]['revision'])

    try:
        dbcursor.execute(query)
    except Exception as e:
        if e.pgcode != None:
            print("ERROR: Query failed to fetch! %r" % e.pgerror)
            print("ERROR: Query that failed: %r" % query)
    #line = dbcursor.fetchone()

#
# Parse the XML file from the test run
#
for xml in infiles:
    spin = PixelSpinner("Processing " + os.path.basename(xml) + "...")
    doc = etree.parse(xml)
    tests = list()
    testenv = dict()
    for docit in doc.getiterator():
        test = dict()
        # print("TAG: %r" % docit.tag)
        if docit.tag == 'testrun':
            for elit in docit.getiterator():
                # print("FIXME testenv: %r, %r" % (elit.tag, elit.text))
                testenv[elit.tag] = elit.text
                continue
        if docit.tag == 'test':
            # test = {'result': "", 'name': "", 'output': ""}
            test = dict()
            for elit in docit.getiterator():
                # print("FIXME test: %r, %r" % (elit.tag, elit.text))
                if elit.tag == 'test':
                    continue
                elif elit.text:
                    # Cleanup the text
                    text = elit.text.rstrip('/')
                    colon = text.find(': ')
                    if colon > 0:
                        text = text[colon+1:]
                else:
                    text = ""
                test[elit.tag] = text
            tests.append(test)

            query = "INSERT INTO tests(testrun, result, name, tool, output) VALUES(%r, %r, %r, %r, %r)" % (testrun, test['result'], test['name'], testenv['tool'], test['output'])
            spin.next()            
            dbcursor.execute(query)
    #doc.close()

#
# Update the testruns table
#
# FIXME: should use a date from the XML file
query = """INSERT INTO testruns(testrun, date, target, build) VALUES(%r, %r, %r, %r)""" % (testrun, testenv['timestamp'], testenv['target'], testenv['build'])
try:
    dbcursor.execute(query)
except Exception as e:
    if e.pgcode != None:
        print("ERROR: Query failed to fetch! %r" % e.pgerror)
        print("ERROR: Query that failed: %r" % query)

