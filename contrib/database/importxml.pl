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
use XML::Parser;

## Parse command options

my %OPT = ();

GetOptions('help'	=>	\$OPT{help},
	   'verbose|v+'	=>	\$OPT{verbose},
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
  my $get_manifest_st = $DB->prepare
    (q[SELECT manifest FROM dejagnu.manifests WHERE sha1sum = ?]);
  my $ins_manifest_st = $DB->prepare
    (q[INSERT INTO dejagnu.manifests (sha1sum) VALUES (?) RETURNING manifest]);
  my $ins_package_st = $DB->prepare
    (q[INSERT INTO dejagnu.manifest_packages]
     .q[ (manifest, package, src_url, filespec, branch,]
     .q[  md5sum, revision, configure_options) VALUES (?,?,?,?,?,?,?,?)]);

  if ($DB->selectrow_array($chk_manifest_st, undef, $Manifest{sha1sum})) {
    print "manifest $Manifest{sha1sum} already in database\n";
    $Manifest{DB_id} = $DB->selectrow_array($get_manifest_st, undef,
					    $Manifest{sha1sum});
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
    $Manifest{DB_id} = $manifest;
    $DB->commit;
  }
}

## Import XML test result files

{
  my $ins_run_st = $DB->prepare
    (q[INSERT INTO dejagnu.runs (start, finish, target, host, build)]
     .q[ VALUES (?,?,?,?,?) RETURNING run]);
  my $upd_run_finish_st = $DB->prepare
    (q[UPDATE dejagnu.runs SET finish = ? WHERE run = ?]);
  my $ins_group_st = $DB->prepare
    (q[SELECT dejagnu.intern_set_by_name(?) AS set_id]);
  my $ins_result_st = $DB->prepare
    (q[INSERT INTO dejagnu.results]
     .q[ (run, set, result, name, input, output, prmsid)]
     .q[ VALUES (?,?,?,?,?,?,?)]);
  my $ins_manifest_run_st = $DB->prepare
    (q[INSERT INTO dejagnu.manifest_runs (manifest, run) VALUES (?,?)]);

  my $DB_run_id = undef;	# row id in dejagnu.runs
  my $DB_set_id = undef;	# row id in dejagnu.sets

  # XML parsing state variables
  my $start_time = undef;	# timestamp from dg:start on dg:run
  my $user_name = undef;	# user login name from dg:user on dg:run
  my $finish_time = undef;	# timestamp from dg:finish on dg:summary

  my $current_board_id = undef;	# XML id of currently open dg:board
  # hash of collected board information:
  #  id => hash as record:
  #	arch => arch tuple
  #	name => name
  #	roles => array of hash as record:
  #		as => build | host | target
  #		for => element or tool or in-general if omitted
  my %boards = ();
  # hash mapping role to primary board id
  my %gen_board = ();

  # array of currently-open test group names
  my @groups = ();

  # hash of collected test information, per-test
  #  result => PASS | FAIL | ...
  #  prms_id => PRMS ID if reported
  #  bug_id => bug ID if reported
  #  name => name from inner dg:name tag
  #  input => input text from inner dg:input tag if reported
  #  output => output text from inner dg:output tag if reported
  my %test_info = ();

  my $parser = XML::Parser->new(Namespaces => 1);
  $parser->setHandlers
    (Init => sub {
       my $p = shift;

       # reset state variables
       $DB_run_id = undef; $DB_set_id = undef;
       $start_time = undef; $finish_time = undef; $user_name = undef;
       $current_board_id = undef; %boards = (); %gen_board = ();
       @groups = (); %test_info = ();

       $DB->begin_work;
     },
     Final => sub {
       my $p = shift;

       $upd_run_finish_st->execute($finish_time, $DB_run_id);
       $ins_manifest_run_st->execute($Manifest{DB_id}, $DB_run_id)
	 if $Manifest{DB_id};
       $DB->commit;
     },
     Start => sub {
       my $p = shift;
       my $tag = shift;
       my %attr = @_;

       if ($tag eq 'test') {
	 $test_info{result} = $attr{result};
	 $test_info{bug_id} = $attr{bug_id} if $attr{bug_id};
	 $test_info{prms_id} = $attr{prms_id} if $attr{prms_id};
       } elsif ($tag eq 'group') {
	 push @groups, $attr{name};
	 $DB_set_id = $DB->selectrow_array($ins_group_st, undef,
					   join('/', @groups));
       } elsif ($tag eq 'board') {
	 $current_board_id = $attr{id};
	 $boards{$attr{id}}{arch} = $attr{arch};
	 $boards{$attr{id}}{name} = $attr{name};
       } elsif ($tag eq 'role') {
	 $p->xpcroak('"role" tag outside of "board" tag')
	   unless $current_board_id;
	 push @{$boards{$current_board_id}{roles}}, {@_};
       } elsif ($tag eq 'summary') {
	 $finish_time = $attr{finish};
       } elsif ($tag eq 'run') {
	 $start_time = $attr{start};
	 $user_name = $attr{user} if $attr{user};
       }
     },
     End => sub {
       my $p = shift;
       my $tag = shift;

       if ($tag eq 'test') {
	 print join(': ', join('/', @groups), @test_info{qw/result name/}),
	   "\n" if $OPT{verbose};
	 $ins_result_st->execute
	   ($DB_run_id, $DB_set_id,
	    @test_info{qw/result name input output prms_id/});
	 %test_info = ();
       } elsif ($tag eq 'group') {
	 pop @groups;
	 if (@groups)
	   { $DB_set_id = $DB->selectrow_array($ins_group_st, undef,
					       join('/', @groups)) }
	 else { $DB_set_id = undef }
       } elsif ($tag eq 'board') {
	 $current_board_id = undef;
       } elsif ($tag eq 'platform') {
	 foreach my $id (keys %boards)
	   { foreach my $role (@{$boards{$id}{roles}})
	       { $gen_board{$role->{as}} = $id unless $role->{for} } }
	 if ($OPT{verbose}) {
	   print "Tests run at $start_time by $user_name\n";
	   foreach my $id (sort keys %boards) {
	     print 'board ',$id,': ',
	       $boards{$id}{name},' on ',$boards{$id}{arch},"\n";
	     foreach my $role (@{$boards{$id}{roles}}) {
	       print '    as ',$role->{as};
	       print ' for ',$role->{for} if $role->{for};
	       print "\n";
	     }
	   }
	   print 'primary:  ';
	   print $_,': ',$gen_board{$_},'  ' for qw/build host target/;
	   print "\n";
	 }
	 $DB_run_id = $DB->selectrow_array
	   ($ins_run_st, undef, $start_time, $start_time,
	    map {$boards{$gen_board{$_}}{arch}} qw/build host target/);
       }
     },
     Char => sub {
       my $p = shift;
       my $text = shift;

       $test_info{$p->current_element} .= $text;
     });
  $parser->parsefile($_) for @ARGV;
}

__END__

=head1 NAME

importxml.pl - import DejaGNU XML output into a database

=head1 SYNOPSIS

  importxml.pl [options] xmlfile...

   Options:
     -d, --database	database (default: PostgreSQL default)
     -U, --username	username for connecting to database
     -m, --manifest	manifest file name
     -v, --verbose	select verbose mode
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

=item B<-v>, B<--verbose>

Select verbose mode.

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

=head1 SEE ALSO

L<DBI>, L<DBD::Pg>

=head1 AUTHORS

Jacob Bachmeyer
