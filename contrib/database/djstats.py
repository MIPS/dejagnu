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

# import pdb
import psycopg2
from sys import argv


class DjStats(object):
    def __init__(self, psqldb):
        """This contains the data for a single tool's testrun """
        self.tstats = { 'PASS': 0, 'FAIL': 0, 'XPASS': 0, 'XFAIL': 0, 'UNTESTED': 0, 'UNSUPPRTED': 0 }
        self.post = psqldb
        self.tool = None
        self.testrun = None

    def getStats(self):
        return self.tstats

    def populate(self, tool, testrun):
        self.tool = tool
        self.testrun = testrun
        tstats = dict()
        query = "SELECT COUNT(result) FROM tests WHERE testrun=%r AND tool=%r AND result='FAIL'" % (testrun, tool)
        try:
            self.post.execute(query)
        except Exception as e:
            if e.pgcode != None:
                print("ERROR: Query failed to fetch! %r" % e.pgerror)
                quit()
        tmp = self.post.fetchone()
        if not tmp or len(tmp) < 1:
            self.tstats['FAIL'] = 0
        else:
            self.tstats['FAIL'] = int(tmp[0])

        query = "SELECT COUNT(result) FROM tests WHERE testrun=%r AND tool=%r AND result='PASS'" % (testrun, tool)
        try:
            self.post.execute(query)
        except Exception as e:
            if e.pgcode != None:
                print("ERROR: Query failed to fetch! %r" % e.pgerror)
                quit()
        tmp = self.post.fetchone()
        if not tmp or len(tmp) < 1:
            self.tstats['PASS'] = 0
        else:
            self.tstats['PASS'] = int(tmp[0])

        query = "SELECT COUNT(result) FROM tests WHERE testrun=%r AND tool=%r AND result='XFAIL'" % (testrun, tool)
        try:
            self.post.execute(query)
        except Exception as e:
            if e.pgcode != None:
                print("ERROR: Query failed to fetch! %r" % e.pgerror)
                quit()
        tmp = self.post.fetchone()
        if not tmp or len(tmp) < 1:
            self.tstats['XFAIL'] = 0
        else:
            self.tstats['XFAIL'] = int(tmp[0])

        query = "SELECT COUNT(result) FROM tests WHERE testrun=%r AND tool=%r AND result='XPASS'" % (testrun, tool)
        try:
            self.post.execute(query)
        except Exception as e:
            if e.pgcode != None:
                print("ERROR: Query failed to fetch! %r" % e.pgerror)
                quit()
        tmp = self.post.fetchone()
        if not tmp or len(tmp) < 1:
            self.tstats['XPASS'] = 0
        else:
            self.tstats['XPASS'] = int(tmp[0])

        query = "SELECT COUNT(result) FROM tests WHERE testrun=%r AND tool=%r AND result='UNTESTED'" % (testrun, tool)
        try:
            self.post.execute(query)
        except Exception as e:
            if e.pgcode != None:
                print("ERROR: Query failed to fetch! %r" % e.pgerror)
                quit()
        tmp = self.post.fetchone()
        if not tmp or len(tmp) < 1:
            self.tstats['UNTESTED'] = 0
        else:
            self.tstats['UNTESTED'] = int(tmp[0])

        query = "SELECT COUNT(result) FROM tests WHERE testrun=%r AND tool=%r AND result='UNSUPPORTED'" % (testrun, tool)
        try:
            self.post.execute(query)
        except Exception as e:
            if e.pgcode != None:
                print("ERROR: Query failed to fetch! %r" % e.pgerror)
                quit()
        tmp = self.post.fetchone()
        if not tmp or len(tmp) < 1:
            self.tstats['UNSUPPORTED'] = 0
        else:
            self.tstats['UNSUPPORTED'] = int(tmp[0])

    def dump(self):
        if self.tstats['PASS'] > 0 or self.tstats['FAIL'] > 0:
            print("Statistics for Test Run for %s: #%d" % (self.tool, self.testrun))
            print("\tPassed: %d" % self.tstats['PASS'])
            print("\tFailed: %d" % self.tstats['FAIL'])
            print("\tXPassed: %d" % self.tstats['XPASS'])
            print("\tXFailed: %d" % self.tstats['XFAIL'])
            print("\tUntested: %d" % self.tstats['UNTESTED'])
            print("\tUnsupported: %d" % self.tstats['UNSUPPORTED'])
            # if branch and not filespec:
            #     print("\tBranch: %s" % branch)
            # elif not branch and filespec:
            #     print("\tFile: %s" % filespec)
