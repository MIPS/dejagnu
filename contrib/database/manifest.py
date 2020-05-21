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


import pdb
import psycopg2
import re
from datetime import datetime
from sys import argv


class AbeManifest(object):
    def __init__(self, psqldb):
        """Read a manifest file as produced by ABE"""
        self.post = psqldb
        self.manifest = dict()

    def readManifest(self, filespec):
        #
        # Read manifest file
        #
        file = open(filespec, 'r')
        done = False
        tool = None
        oldtool = None
        key = None
        value = None
        data = dict()
        patterns = ("^target",
                    ".*_branch",
                    ".*_filespec",
                    ".*_revision",
                    ".*_url",
                    ".*_md5sum")
        lines = file.readlines()
        for line in lines:
            # skip comments or blank lines
            if len(line) <= 1 and line[0] == '\n':
                self.manifest[tool] = data
                data = dict()
                continue
            if line.find('=') <= 0:
                continue
            # We only want a subset of the fields.
            for pat in patterns:
                m = re.match(pat + "=.*$", line.strip(), re.IGNORECASE)
                if m is not None:
                    tmp = line.split('=')
                    tool = tmp[0].split('_')[0]
                    key = tmp[0].split('_')
                    if len(key) == 1:
                        key = key[0]
                    else:
                        key = key[1]
                    value = tmp[1].strip()
                    data[key] = value

    def insert(self, testrun):
        for tool,entry in self.manifest.items():
#            if not tool:
#                continue
            query = "INSERT INTO manifest(testrun, tool) VALUES('%d', %r)" % (testrun, tool)
            # try:
            #     self.post.execute(query)
            # except Exception as e:
            #     if e.pgcode != None:
            #         print("ERROR: Query failed to fetch! %r" % e.pgerror)
            #         print("ERROR: Query that failed: %r" % query)
            #         quit()

            if len(entry) ==0:
                continue

            if 'branch' in entry and 'revision' in entry:
                query = """INSERT INTO manifest(testrun, tool, branch, revision) VALUES(%r, %r, %r, %r);""" % (testrun,  tool, entry['branch'], entry['revision'])
            elif 'filespec' in entry and 'md5sum' in entry:
                query = """INSERT INTO manifest(testrun, tool, filespec, md5sum) VALUES(%r, %r, %r, %r);"""% (testrun, tool, entry['filespec'], entry['md5sum'])
            elif 'filespec' in entry and 'md5sum' not in entry:
                query = """INSERT INTO manifest(testrun, tool, filespec) VALUES(%r, %r, %r);"""% (testrun, tool, self.manifest[tool]['filespec'])
            elif not 'filespec' in entry and 'md5sum' in entry:
                continue
            elif not 'branch' in entry and 'revision' in entry:
                continue

            try:
                self.post.execute(query)
            except Exception as e:
                if e.pgcode != None:
                    print("ERROR: Query failed to fetch! %r" % e.pgerror)
                    print("ERROR: Query that failed: %r" % query)
                    quit()

    def queryManifest(self):
        pass
        # query = "SELECT branch,filespec,revison.md5sum FROM manifest WHERE testrun=%r AND tool='gcc'" % (testrun)
        # try:
        #     self.post.execute(query)
        # except Exception as e:
        #     if e.pgcode != None:
        #         print("ERROR: Query failed to fetch! %r" % e.pgerror)
        #         quit()
        # tmp = self.post.fetchone()
        # if tmp:
        #     self.branch = tmp[0]
        #     self.filespec = tmp[1]
        # else:
        #     self.branch = None
        #     self.filespec = None

    def dump(self):
        for tool,entry in self.manifest.items():
            if tool:
                if len(entry) > 1:
                    print("Details for %s" % tool)
                    for key,value in entry.items():
                        print("\t%s_%s = %s" % (tool, key, value))
