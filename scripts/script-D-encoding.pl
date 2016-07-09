#!/usr/bin/perl -W

use C3TT::Client;
use CRS::Executor;
use boolean;

my $tracker = C3TT::Client->new();
my $ticket = $tracker->assignNextUnassignedForState('encoding', 'encoding');

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for encoding\n";
} else {
	my $tid = $ticket->{id};
	my $props = $tracker->getTicketProperties($tid);
	print "encoding ticket # $tid for Fahrplan ID $props->{'Fahrplan.ID'}\n";

	my $jobxml = $tracker->getJobfile($tid);

	my $ex = new CRS::Executor($jobxml);

	unless (defined($ex)) {
		$tracker->setTicketFailed($tid, "Encoding script: instantiating job executor failed!");
		exit;
	}

	my $time = time;
	my $return = 0;

	eval {
		$return = $ex->execute();
	};

	$time = time - $time;

	$log = join ("\n", $ex->getOutput());
	utf8::encode($log);

	if ($return) {
		$tracker->addLog($tid, $log);
		$tracker->setTicketDone($tid, "Encoding tasks completed in $time seconds");
		# indicate short sleep to wrapper script
		exit(100);
	} else {
		$tracker->addLog($tid, $log);
		$tracker->setTicketFailed($tid, "Encoding tasks failed!");
	}
}
