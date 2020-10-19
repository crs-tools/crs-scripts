#!/usr/bin/perl

use strict;
use warnings;
use charnames ':full';

BEGIN { push @INC, '../tracker3.0/lib'; }

use CRS::Executor;
use Sys::Hostname;
use XML::Simple qw(:strict);
use Encode;

my $jobfile = $ARGV[0];
my $jobtype = $ARGV[1];

if (!defined($jobfile)) {
    print "\n\nUsage:\n\tperl execute-jobfile.pl <path to jobfile> [jobtype] \n\n";
    exit 1;
}

my $ex = new CRS::Executor($jobfile);
$ex->execute($jobtype);

