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
        """)
    quit()

# Default values
dbname = "dejagnu"
infiles = ""
manifest = None
testrun = None
clean = False

try:
    (opts, vals) = getopt.getopt(argv[1:], "h,m:,d:,t:,c", ["help", "manifest", "database", "testrun", "clean"])
    for (opt, val) in opts:
        if opt == '--help' or opt == '-h':
            usage(argv)
        elif opt == "--testrun" or opt == '-t':
            testrun = val
        elif opt == "--clean" or opt == '-c':
            clean = True
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
    query = "DELETE FROM manifest WHERE testrun=%r;" % testrun
