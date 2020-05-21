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
# DejaGnu files
from djstats import DjStats
from manifest import AbeManifest


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
testrun = 0

try:
    (opts, vals) = getopt.getopt(argv[1:], "h,m:,d:,t:", ["help", "manifest", "database", "testrun"])
    for (opt, val) in opts:
        if opt == '--help' or opt == '-h':
            usage(argv)
        elif opt == "--testrun" or opt == '-t':
            testrun = int(val)
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
if not infiles:
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
if testrun <= 0:
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
# Read the ABE manifest data for this build, which contains their
# details for each component of this toolchain build.
#
abem = AbeManifest(dbcursor)
if manifest:
    # Read data from a text file
    abem.readManifest(manifest)
    abem.insert(testrun)
else:
    # Read data from the database
    abem.populate(testrun)
# abem.dump()


#
# Parse the XML file from the test run
#
allstats = dict()
fails = dict()
for xml in infiles:
    gstats = DjStats(dbcursor)
    spin = PixelSpinner("Processing " + os.path.basename(xml) + "...")
    # Ignore invalid charcters.
    fd = open(xml)
    parser = etree.XMLParser(recover=True)
    doc = etree.parse(fd, parser)

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
            if  test['result'] == 'FAIL':
                fails[testenv['tool']] = test['output']
            query = "INSERT INTO tests(testrun, result, name, tool, output) VALUES(%r, %r, %r, %r, %r)" % (testrun, test['result'], test['name'], testenv['tool'], test['output'])
            spin.next()            
            dbcursor.execute(query)
    gstats.populate(testenv['tool'], testrun)
    allstats[testenv['tool']] = gstats

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

for tool,gstats in allstats.items():
    gstats.dump()

for ff in fails:
    print(ff)
