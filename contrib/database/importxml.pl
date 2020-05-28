#!/usr/bin/perl
# -*- CPerl -*-

# importxml.pl -- import DejaGnu XML output into PostgreSQL database
#
# Copyright (C) 2020 Free Software Foundation, Inc.
#
# This file is part of DejaGnu.
#
# DejaGnu is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

use strict;
use warnings;

use Getopt::Long;
use Digest::SHA;
use Pod::Usage;

use DBI;
use XML::Twig;

## Parse command options

my %OPT = ();

GetOptions('help'	=>	\$OPT{help},
	   'database|d=s' =>	\$OPT{database},
	   'manifest|m=s' =>	\$OPT{manifest},
	   'username|U=s' =>	\$OPT{db_username},
	  ) or pod2usage(2);
pod2usage(1) if $OPT{help};

pod2usage("$0: No input files given.") if @ARGV == 0;

## Connect to database

my $DB;
{
  my $dsn = 'dbi:Pg:';

  if ($OPT{database}) {
    if ($OPT{database} =~ m/^dbi:/)
      { $dsn = $OPT{database} }
    else
      { $dsn .= 'dbname='.$OPT{database} }
  } elsif ($ENV{DBI_DSN}) { $dsn = $ENV{DBI_DSN} }

  $DB = DBI->connect($dsn, $OPT{db_username}, undef,
		     { AutoCommit => 1, RaiseError => 1 })
    or die $DBI::errstr;
}

## Import manifest if given

# Hash storing manifest information
#  Keys:
#   format		-- manifest type
#   format_version	-- manifest format revision
#   packages		-- hash of package records; keyed on pacakge name
#   sha1sum		-- hex SHA-1 digest of manifest file
#  Each element in "packages" hash is a hash.
#   Keys:
#    src_url		-- tarball or repository location
#    filespec		-- tarball or repository name
#    branch		-- revision control branch name
#    md5sum		-- tarball digest
#    revision		-- revision control commit identifier
#    configure_opt	-- options passed to configure script
my %Manifest = ();
if ($OPT{manifest}) {
  my $digest = Digest::SHA->new('SHA-1');
  open MANIFEST, '<', $OPT{manifest} or die "$OPT{manifest}: $!";

  $_ = <MANIFEST>; $digest->add($_); chomp;
  if (m/^manifest_format=([[:digit:].]+)/) {
    # autodetect ABE manifest
    $Manifest{format} = 'abe';
    $Manifest{format_version} = $1;

    my %keymap = ((map { $_ => $_ } (qw/filespec branch revision md5sum/)),
		  qw/  url src_url    configure configure_opt/);

    while (<MANIFEST>) {
      $digest->add($_); chomp;
      next if m/^$/;	# skip blank lines
      if (m/^([^_]+)_(url|filespec|branch|md5sum|revision|configure)=(.*)$/) {
	my $name = $1; my $key = $2; my $value = $3;
	$value =~ s/^"(.*)"$/$1/;
	$Manifest{packages}{$name}{$keymap{$key}} = $value;
      }
    }
  } else
    { die "manifest '$OPT{manifest}' not in any known format" }

  close MANIFEST or die "close $OPT{manifest}: $!";
  $Manifest{sha1sum} = $digest->hexdigest;

  my $chk_manifest_st = $DB->prepare
    (q[SELECT COUNT(*) FROM dejagnu.manifests WHERE sha1sum = ?]);
  my $ins_manifest_st = $DB->prepare
    (q[INSERT INTO dejagnu.manifests (sha1sum) VALUES (?) RETURNING manifest]);
  my $ins_package_st = $DB->prepare
    (q[INSERT INTO dejagnu.manifest_packages]
     .q[ (manifest, package, src_url, filespec, branch,]
     .q[  md5sum, revision, configure_options) VALUES (?,?,?,?,?,?,?,?)]);

  if ($DB->selectrow_array($chk_manifest_st, undef, $Manifest{sha1sum})) {
    print "manifest $Manifest{sha1sum} already in database\n"
  } else {
    print "adding manifest $Manifest{sha1sum} to database\n";

    $DB->begin_work;
    my $manifest = $DB->selectrow_array($ins_manifest_st, undef,
					$Manifest{sha1sum});
    $ins_package_st->execute
      ($manifest, $_, @{$Manifest{packages}{$_}}{qw/src_url filespec branch
						    md5sum revision
						    configure_opt/})
	for sort keys %{$Manifest{packages}};
    $DB->commit;
  }
}

## Import XML test result files

# TODO: implement

__END__

=head1 NAME

importxml.pl - import DejaGNU XML output into a database

=head1 SYNOPSIS

  importxml.pl [options] xmlfile...

   Options:
     -d, --database	database (default: PostgreSQL default)
     -m, --manifest	manifest file name
     --help		display this help and exit

=head1 OPTIONS

=over

=item B<-d>, B<--database>

Specify the target database.  This option can accept a simple database name
or a DBI DSN beginning with C<dbi:>.  Default is to connect to Postgres
using its own defaults.

=item B<-m>, B<--manifest>

Specify a manifest file.  Additional information about the tools tested is
imported from this file.  Currently the manifests written by ABE are
supported.

=item B<-U>, B<--username>

Specify a username for connecting to the target database.

=back

=head1 DESCRIPTION

This script imports test results from DejaGnu XML-format logs into a
relational database for subsequent analysis.  Currently only the PostgreSQL
RDBMS is supported.  These tools are very much works-in-progress.

=head1 ENVIRONMENT

=over

=item B<DBI_DSN>

Fallback default DSN if set and C<--database> option not given.

=back

=head1 FILES

=head1 EXAMPLES

=head1 DIAGNOSTICS

=head1 SEE ALSO

L<DBI>, L<DBD::Pg>

=head1 AUTHORS

Jacob Bachmeyer

=head1 CAVEATS
