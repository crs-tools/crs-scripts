#!/usr/bin/perl -W

use CRS::Tracker::Client;
use boolean;
use Sys::Hostname;

my $tracker = CRS::Tracker::Client->new();
my $state = $ENV{CRS_STATE} // 'postprocessing';
my $ticket;

if (defined($ENV{'CRS_ROOM'}) && $ENV{'CRS_ROOM'} ne '') {
        my $filter = {};
        $filter->{'Fahrplan.Room'} = $ENV{'CRS_ROOM'};
        $ticket = $tracker->assignNextUnassignedForState('encoding', $state, $filter);
} else {
        my $filter = {};
        $filter->{'EncodingProfile.IsMaster'} = 'no';
        $ticket = $tracker->assignNextUnassignedForState('encoding', $state, $filter);
}

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for $state\n";
} else {
	my $tid = $ticket->{id};
	print "$state ticket # $tid\n";

	my $props = $tracker->getTicketProperties($tid);
	if (defined($props->{'Fahrplan.Recording.Optout'}) && $props->{'Fahrplan.Recording.Optout'} eq '1') {
		print "Ticket is opt-out!!\n\n";
		$tracker->setTicketFailed($tid, 'Recording has optout-flag!');
		exit(100);
	}

	if (defined($props->{'Fahrplan.GUID'}) && $props->{'Fahrplan.GUID'} =~ /^FIXME/i) {
		print "Ticket has FIXME GUID!\n\n";
		$tracker->setTicketFailed($tid, 'Recording has invalid Fahrplan.GUID!');
		exit(100);
	}

	if ($props->{'EncodingProfile.IsMaster'} eq 'yes') {
		$tracker->addLog($tid, "WARNING: applying $state dummy on master ticket");
	}

	$tracker->setTicketDone($tid, "Encoding $state skipped via dummy");
	exit(100);
}
