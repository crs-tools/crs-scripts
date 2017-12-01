#!/usr/bin/perl -W

use CRS::Tracker::Client;
use CRS::Executor;
use Proc::ProcessTable;
use boolean;
use sigtrap qw/handler signal_handler normal-signals/;

my $tracker = CRS::Tracker::Client->new();
my $start = time;
my $taskcount = 1;
my $abortion = 0;
my $termination = 0;

sub signal_handler {
	$termination = 1;
}

sub check_exit {
	my $code = shift;
	exit($code) unless $termination == 1;
	exit(250);
}

sub check_voctomix {
	my $t = new Proc::ProcessTable;
	foreach $p ( @{$t->table} ){
		my $cmd = $p->cmndline;
		if ($cmd =~ /python.*voctocore.py/) {
			return 1;
		}
	}
	return 0;
}

if (check_voctomix()) {
	print "\n\n Voctomix detected! NOT encoding!\n\n";
	sleep 5;
	exit(0);
}

my $ticket = $tracker->assignNextUnassignedForState('encoding', 'encoding');

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
		check_exit(1);
	}

	my $return = 0;
	my $time = $start;

	eval {
		$return = $ex->execute();
	};

	$time = time - $time;

	if ($return) {
		# this is too verbose:
		# $log = join ("\n", $ex->getOutput());
		# $tracker->addLog($tid, $log);

		$tracker->setTicketDone($tid, "Encoding tasks completed in $time seconds");
		# indicate short sleep to wrapper script
		check_exit(100);
	} else {
		$log = join ("\n", $ex->getErrors());
		print STDERR "$log\n";
		$tracker->addLog($tid, $log) if ($log && $log ne '');
		# do not try to set failed if we aborted because of tracker issues:
		$tracker->setTicketFailed($tid, "Encoding tasks failed!") unless $abortion;
	}
}

check_exit(0);

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
	return 0; # -1 if temporary output files should be deleted
}
