#!/usr/bin/perl -W

use CRS::Tracker::Client;
use boolean;
use Sys::Hostname;

my $filter = {};
if (defined($ENV{'CRS_ISMASTER'}) && $ENV{'CRS_ISMASTER'} ne '') {
	$filter->{'EncodingProfile.IsMaster'} = $ENV{'CRS_ISMASTER'};
}

my $tracker = CRS::Tracker::Client->new();
my $ticket = $tracker->assignNextUnassignedForState('encoding', 'checking', $filter);

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for checking\n";
} else {
	my $tid = $ticket->{id};
	print "postprocessing ticket # $tid\n";

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
		$tracker->addLog($tid, "WARNING: applying checking dummy on master ticket");
	}

	$tracker->setTicketDone($tid, 'Subformat was checked automatically');
	exit(100);
}
