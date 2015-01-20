#!/usr/bin/perl -W

require POSIX;
require CRS::Fuse::VDV;
require C3TT::Client;

use POSIX qw(strftime);
use boolean;

my $target_type = 'recording';
my $target_state = 'recording';

# default padding of record start and stop:
my $startpadding = 300;
my $endpadding = 900;

# filter recording events
print "my time base now: " . strftime('%FT%TZ', gmtime(time)). "\n";
my $start_filter = {};
$start_filter->{'Record.StartedBefore'} = strftime('%FT%TZ', gmtime(time + $startpadding));
my $end_filter = {};
$end_filter->{'Record.EndedBefore'} = strftime('%FT%TZ', gmtime(time - $endpadding));

#######################################

$|=1;

my $tracker = C3TT::Client->new();

my $tickets_left = 1;

while($tickets_left) {
    print "querying for ticket with next state $target_state";
    print " ...";
    my $ticket = $tracker->assignNextUnassignedForState($target_type, $target_state, $start_filter);
	print "\n";
	if(!$ticket) {
	    $tickets_left = 0;
		print "no tickets to be to moved to state $target_state. exiting...\n";
		last;
	}

    print "found ticket #" . $ticket->{id} . ". ";
}

# find assigned tickets in state recording

print "querying for assigned ticket in state $target_state ...\n";
my $tickets = $tracker->getAssignedForState($target_type, $target_state, $end_filter);

if (!($tickets) || 0 == scalar(@$tickets)) {
    print "no assigned tickets currently $target_state. exiting...\n";
    # since this script handles more than one ticket per execution, we do not 
    # use the special exit code for short sleep
    exit 0;
}

print "found " . scalar(@$tickets) ." tickets\n";
foreach (@$tickets) {
    my $ticket = $_;
    print "found ticket #" . $ticket->{id} . ". set done. ";

    $tracker->setTicketDone($ticket->{id});
    print "sleeping a second...\n";
    sleep 1;
}

print "exit";
