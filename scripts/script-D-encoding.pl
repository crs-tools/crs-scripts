#!/usr/bin/perl -W

use C3TT::Client;
use CRS::Executor;
use boolean;

my $tracker = C3TT::Client->new();
my $ticket = $tracker->assignNextUnassignedForState('encoding', 'encoding');
my $start = time;
my $taskcount = 1;
my $abortion = 0;

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for encoding\n";
} else {
	my $tid = $ticket->{id};
	my $props = $tracker->getTicketProperties($tid);
	print "encoding ticket # $tid for Fahrplan ID $props->{'Fahrplan.ID'}\n";

	my $jobxml = $tracker->getJobfile($tid);

	my $ex = new CRS::Executor($jobxml);
	$ex->setPreTaskFinishCallback(\&checkTicketStatus);

	unless (defined($ex)) {
		$tracker->setTicketFailed($tid, "Encoding script: instantiating job executor failed!");
		exit;
	}

	my $return = 0;
	my $time = $start;

	eval {
		$return = $ex->execute();
	};

	$time = time - $start;

	if ($return) {
		# this is to verbose:
		# $log = join ("\n", $ex->getOutput());
		# $tracker->addLog($tid, $log);

		$tracker->setTicketDone($tid, "Encoding tasks completed in $time seconds");
		# indicate short sleep to wrapper script
		exit(100);
	} else {
		$log = join ("\n", $ex->getErrors());
		$tracker->addLog($tid, $log);
		# do not try to set failed if we aborted because of tracker issues:
		$tracker->setTicketFailed($tid, "Encoding tasks failed!") unless $abortion;
	}
}

sub checkTicketStatus() {
	my $caller = shift;
	my $ping = $tracker->ping($ticket->{id});

	if ($ping eq 'OK') {
		my $secs = time - $start;
		$tracker->addLog($ticket->{id}, "task $taskcount completed after $secs seconds.");
		$start = time;
		$taskcount++;
		return 1;
	}
	my $files = join (', ', $caller->getTemporaryFiles());
	$tracker->addLog($ticket->{id}, "Aborting command execution after task $taskcount, leaving stale encoded files: $files");
	$abortion = 1;
	return 0;
}
