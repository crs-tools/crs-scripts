#!/usr/bin/perl

use strict;
use warnings;
use charnames ':full';

BEGIN { push @INC, '../tracker3.0/lib'; }

use C3TT::Client;
use CRS::Executor;
use Sys::Hostname;
use XML::Simple qw(:strict);
use Encode;

my ($host)     = split(m{\.}o, Sys::Hostname::hostname(), 2);
my $base_url   = $ENV{'CRS_TRACKER'};
my $token      = $ENV{'CRS_TOKEN'};
my $password   = $ENV{'CRS_SECRET'};
my $ticketid   = $ARGV[0];

if (!defined($ticketid)) {
    print "\n\nUsage:\n\tperl get-commands.pl <ticket ID> \n\n\tRemember, the ticket ID is NOT the Fahrplan ID!\n\n";
    exit 1;
}

my $tracker = C3TT::Client->new($base_url, $token, $password) or die "Cannot init tracker";
my $jobxml = $tracker->getJobfile($ticketid);
my $ex = new CRS::Executor($jobxml);
$ex->printParsedCommands();

