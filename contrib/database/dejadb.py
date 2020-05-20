#!/usr/bin/python3

# dejadb.py - Manipulate the DejaGnu database in Postgresql
#
# Copyright (C) 2020 Free Software Foundation, Inc.
#
# This file is part of DejaGnu.
#
# DejaGnu is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

import os
import sys
import getopt
import pdb
import re
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
\t--clean(-c)     Delete all data for the specified testrun
\t--stats(-s) [tool] Display statistics on a testrun (default, all)
\t--fails(-f) [tool] Display failures on a testrun (default, all)
        """)
# \t--compare(-i)   Compare two test runs
    quit()

# Default values
dbname = "dejagnu"
infiles = ""
manifest = None
testrun = None
clean = False
stats = False
fails = False

# All the components that should be in the database in some form
all = ("gcc", "gas", "ld", "g++", "gfortran", "go", "lto", "java", "ada", "gas", "ld", "dejagnu")

try:
    (opts, vals) = getopt.getopt(argv[1:], "h,m:,d:,t:,c,s:,f:", ["help", "manifest", "database", "testrun", "clean", "stats", "fails"])
    for (opt, val) in opts:
        if opt == '--help' or opt == '-h':
            usage(argv)
        elif opt == "--testrun" or opt == '-t':
            testrun = int(val)
        elif opt == "--clean" or opt == '-c':
            clean = True
        elif opt == "--stats" or opt == '-s':
            stats = list()
            stats.append(val)
        elif opt == "--fails" or opt == '-f':
            fails = list()
            fails.append(val)
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

if clean and not testrun:
    usage(argv)

if not stats:
    stats = all

#
# Connect to the database
#
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
        testrun = 1
    else:
        testrun = int(tmp[0])

#
# Delete all data in the database for the specified testrun
#
if clean:
    query = "DELETE FROM tests WHERE testrun=%r; DELETE FROM manifest WHERE testrun=%r; DELETE FROM manifest WHERE testrun=%r" % (testrun, testrun, testrun)
    try:
        dbcursor.execute(query)
    except Exception as e:
        if e.pgcode != None:
            print("ERROR: Query failed to fetch! %r" % e.pgerror)
            quit()

#
# Display statistics for a testrun
#
if stats:
    for tool in stats:
        tstats = dict()
        query = "SELECT COUNT(result) FROM tests WHERE testrun=%r AND tool=%r AND result='FAIL'" % (testrun, tool)
        try:
            dbcursor.execute(query)
        except Exception as e:
            if e.pgcode != None:
                print("ERROR: Query failed to fetch! %r" % e.pgerror)
                quit()
        tstats['FAIL'] = dbcursor.fetchone()
        if not tstats['FAIL']:
            tstats['FAIL'] = 0
        else:
            tstats['FAIL'] = int(tstats['FAIL'][0])

        query = "SELECT COUNT(result) FROM tests WHERE testrun=%r AND tool=%r AND result='PASS'" % (testrun, tool)
        try:
            dbcursor.execute(query)
        except Exception as e:
            if e.pgcode != None:
                print("ERROR: Query failed to fetch! %r" % e.pgerror)
                quit()
        tstats['PASS'] = dbcursor.fetchone()
        if not tstats['PASS']:
            tstats['PASS'] = 0
        else:
            tstats['PASS'] = int(tstats['PASS'][0])

        query = "SELECT COUNT(result) FROM tests WHERE testrun=%r AND tool=%r AND result='XFAIL'" % (testrun, tool)
        try:
            dbcursor.execute(query)
        except Exception as e:
            if e.pgcode != None:
                print("ERROR: Query failed to fetch! %r" % e.pgerror)
                quit()
        tstats['XFAIL'] = dbcursor.fetchone()
        if not tstats['XFAIL']:
            tstats['XFAIL'] = 0
        else:
            tstats['XFAIL'] = int(tstats['XFAIL'][0])

        query = "SELECT COUNT(result) FROM tests WHERE testrun=%r AND tool=%r AND result='XPASS'" % (testrun, tool)
        try:
            dbcursor.execute(query)
        except Exception as e:
            if e.pgcode != None:
                print("ERROR: Query failed to fetch! %r" % e.pgerror)
                quit()
        tstats['XPASS'] = dbcursor.fetchone()
        if not tstats['XPASS']:
            tstats['XPASS'] = 0
        else:
            tstats['XPASS'] = int(tstats['XPASS'][0])

        # Get some data from the manifest, all front ends share the same branch
        query = "SELECT branch,filespec FROM manifest WHERE testrun=%r AND tool='gcc'" % (testrun)
        try:
            dbcursor.execute(query)
        except Exception as e:
            if e.pgcode != None:
                print("ERROR: Query failed to fetch! %r" % e.pgerror)
                quit()
        tmp = dbcursor.fetchone()
        if tmp:
            branch = tmp[0]
            filespec = tmp[1]
        else:
            branch = None
            filespec = None

        if tstats['PASS'] > 0 or tstats['FAIL'] > 0:
            print("Statistics for Test Run for %s: #%d" % (tool, testrun))
            print("\tPassed: %d" % tstats['PASS'])
            print("\tFailed: %d" % tstats['FAIL'])
            print("\tXPassed: %d" % tstats['XPASS'])
            print("\tXFailed: %d" % tstats['XFAIL'])
            if branch and not filespec:
                print("\tBranch: %s" % branch)
            elif not branch and filespec:
                print("\tFile: %s" % filespec)
                
#
# Dump the failures
#
if fails:
    for tool in stats:
        tstats = dict()
        # Get some data from the manifest, all front ends share the same branch
        query = "SELECT branch,filespec,revision FROM manifest WHERE testrun=%r AND tool=%r" % (testrun, tool)
        try:
            dbcursor.execute(query)
        except Exception as e:
            if e.pgcode != None:
                print("ERROR: Query failed to fetch! %r" % e.pgerror)
                quit()
        tmp = dbcursor.fetchone()
        if tmp:
            branch = tmp[0]
            filespec = tmp[1]
            revision = tmp[2]
        else:
            branch = None
            filespec = None
            revision = None
        query = "SELECT name,output FROM tests WHERE testrun=%r AND tool=%r AND result='FAIL'" % (testrun, tool)
        # print(query)
        try:
            dbcursor.execute(query)
        except Exception as e:
            if e.pgcode != None:
                print("ERROR: Query failed to fetch! %r" % e.pgerror)
                quit()
        results = dbcursor.fetchall()
        if branch and not filespec and revision:
            print("Failures in branch: %s@%s" %(branch, revision))
        elif not branch and filespec:
            print("Failures in File: %s" % filespec)

        for entry in results:
            print("\t%s" % entry[0])

compare = (1,2)
if compare:    
        query = "SELECT name,output FROM tests WHERE testrun=%r AND tool=%r AND result='FAIL'" % (testrun, tool)
        print(query)
        try:
            dbcursor.execute(query)
        except Exception as e:
            if e.pgcode != None:
                print("ERROR: Query failed to fetch! %r" % e.pgerror)
                quit()
        results = dbcursor.fetchall()
