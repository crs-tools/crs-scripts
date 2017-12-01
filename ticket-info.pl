#!/usr/bin/perl -W

BEGIN { push @INC, 'lib'; }

use IO::Socket::SSL;
use CRS::Tracker::Client;
use Data::Dumper;

die "Please provide CRS settings via env variables (e.g. source tracker-profile.sh)" unless defined($ENV{CRS_TRACKER});
my $tid=shift;
die "Please give ticket ID (not Fahrplan ID) as first argument\n" unless defined ($tid);
my $tracker = CRS::Tracker::Client->new();
my $props = $tracker->getTicketProperties($tid);
print "Properties of Ticket $tid:\n" . Dumper($props). "\n\n";
