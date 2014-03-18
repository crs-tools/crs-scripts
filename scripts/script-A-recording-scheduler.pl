#!/usr/bin/perl -W

require POSIX;
require CRS::Fuse::VDV;
require C3TT::Client;

use POSIX qw(strftime);
use boolean;
use Time::Piece;

my $target_type = 'recording';
my $target_state = 'recording';

# default padding of record start and stop:
my $startpadding = 300;
my $endpadding = 900;

# filter recording events
my $start_filter = {};
$start_filter->{'Record.StartedBefore'} = strftime('%F %T',localtime(time + $startpadding));
my $end_filter = {};
$end_filter->{'Record.EndedBefore'} = strftime('%F %T',localtime(time - $endpadding));

#######################################

$|=1;

my $tracker = C3TT::Client->new();

my $tickets_left = 1;

while($tickets_left) {
    print "querying for ticket with next state $target_state ...";
    my $ticket = $tracker->assignNextUnassignedForState($target_type, $target_state, $start_filter);
	print "\n";
	if(!$ticket) {
	    $tickets_left = 0;
		print "no tickets to be to moved to state $target_state. exiting...\n";
		last;
	}

	print "found ticket #" . $ticket->{id} . ". ";

    if((Time::Piece->strptime($ticket->{time_end},'%Y-%m-%d %T')->epoch - localtime()->tzoffset - time) + $endpadding < 0) {
        print "event has already ended some time ago. set to recorded...\n";
        $tracker->setTicketDone($ticket->{id});
    } else {
        print "set to $target_state. sleeping a second...\n";
    }
	sleep 1;
}

# find assigned tickets in state recording

print "querying for assigned ticket in state $target_state ...\n";
my $tickets = $tracker->getAssignedForState($target_type, $target_state, $end_filter);

if (!($tickets) || 0 == scalar(@$tickets)) {
    print "no assigned tickets currently $target_state. exiting...\n";
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
