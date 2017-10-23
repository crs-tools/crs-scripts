#!/usr/bin/perl -W

use C3TT::Client;
use boolean;
use Sys::Hostname;

my $tracker = C3TT::Client->new();
my $ticket = $tracker->assignNextUnassignedForState('encoding', 'postprocessing');

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for postprocessing\n";
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
		$tracker->addLog($tid, "WARNING: applying postproc dummy on master ticket");
	}

	$tracker->setTicketDone($tid, 'Encoding postprocessor: upload skipped via postproc dummy.');
	exit(100);
}
