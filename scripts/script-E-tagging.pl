#!/usr/bin/perl -W

use C3TT::Client;
use CRS::Executor;
use boolean;

my $tracker = C3TT::Client->new();
my $ticket = $tracker->assignNextUnassignedForState('encoding', 'postencoding');

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for postencoding\n";
} else {
	my $tid = $ticket->{id};
	my $props = $tracker->getTicketProperties($tid);
	print "postencoding ticket # $tid for Fahrplan ID $props->{'Fahrplan.ID'}\n";

	my $jobxml = $tracker->getJobfile($tid);

	my $ex = new CRS::Executor($jobxml);

	unless (defined($ex)) {
		$tracker->setTicketFailed($tid, "Postencoding script: instantiating job executor failed!");
		exit;
	}

	my $time = time;
	my $return = 0;

	eval {
		$return = $ex->execute('postencoding');
	};

	$time = time - $time;
	$log = join ("\n", $ex->getOutput());
	if ($return) {
		$tracker->addLog($tid, $log);
		$tracker->setTicketDone($tid, "Postencoding tasks completed in $time seconds");
		# indicate short sleep to wrapper script
		exit(100);
	} else {
		$tracker->addLog($tid, $log);
		$tracker->setTicketFailed($tid, "Postencoding tasks failed!");
	}
}
