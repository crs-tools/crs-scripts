#!/usr/bin/perl -W

BEGIN { push @INC, 'lib'; }

require C3TT::Client;
require Data::Dumper;

my $tracker = C3TT::Client->new();
my $props = $tracker->getTicketProperties($tid);
print "Properties of Ticket $tid:\n" . Dumper($props). "\n\n";
