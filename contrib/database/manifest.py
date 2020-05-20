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
        line = "#"
        data = dict()
        tool = None
        oldtool = None
        key = None
        value = None
        while len(line) > 0:
            line = file.readline().rstrip()
            if len(line) == 0 or line == '\n' or line.find('#') >= 0:
                line = file.readline()
                continue
            nodes = line.split('=')
            if len(nodes) < 2:
                nodes = line.split(':')
                if len(nodes) == 2:
                    key = nodes[0]
                    value = nodes[1]
                else:
                    key = None
                    value = None
            else:
                key = nodes[0]
                value = nodes[1]

            if not key:
                continue
            patterns = ("^target$", "^host$",  "^host_gcc$", ".*_branch", ".*_filespec", ".*_revision", ".*_md5sum", ".*_configure", ".*_url")
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
                self.manifest[tool] = data
                data = dict()

    def insert(self):
        for tool,entry in self.manifest.items():
            if len(entry) <= 0:
                continue
            # print("FIXME: %r" % entry)
            # If filespec is present, it's from a tarball
            if 'filespec' in entry and 'md5sum' in entry:
                query = """INSERT INTO manifest(testrun, tool, filespec, md5sum) VALUES(%r, %r, %r, %r);"""% (testrun, tool, manifest[tool]['filespec'], manifest[tool]['md5sum'])
            elif 'branch' in entry and 'revision' in entry:
                query = """INSERT INTO manifest(testrun, tool, branch, revision) VALUES(%r, %r, %r, %r);""" % (testrun,  tool, manifest[tool]['branch'], manifest[tool]['revision'])

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
            print("Details for %s" % tool)
            for key,value in entry.items():
                print("\t%s %s, %s" % (tool, key, value))
