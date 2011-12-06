#!/usr/bin/perl -W

require POSIX;
require trackerlib2;
require fusevdv;

# Call this script with hostname, secret and project slug as parameter!

my ($hostname, $secret, $project) = (shift, shift, shift);

# padding of record start and stop:
my $startpadding = 300;
my $endpadding = 300;

#######################################

$|=1;

initTracker('hostname' => $hostname, 'secret' => $secret, 'project' => $project);

foreach ('scheduled', 'recording') {
	my $state = $_;
	print "querying tickets in state $state ...";
	my @tids = getAllUnassignedTicketsInState($state);
	print "\n";
	if (!(@tids) || 0 == scalar(@tids)) {
		print "no tickets currently $state.\n";
		next;
	}
	print "found " . @tids ." tickets\n";
	foreach (@tids) {
		my %ticket = %$_;
		my $tid = $ticket{'id'};
		if (defined($tid) && $tid > 0) {
			print "inspecting ticket # $tid .";

			# fetch metadata

			my %props = getTicketProperties($tid);
			my $startdate = $props{'Fahrplan.Date'};
			my $starttime = $props{'Fahrplan.Start'};
			my $duration = $props{'Fahrplan.Duration'};

			# check minimal metadata

			if (!defined($startdate) || !defined($duration) || !defined($starttime)) {
				print STDERR "NOT ENOUGH METADATA! (ticket# $tid)\n";
				next;
			}

			# transformation of metadata

			print ".";
			my $start = $startdate . '-' . $starttime; # put date and time together
			my ($paddedstart, $paddedend, undef) = getPaddedTimes($start, $duration, $startpadding, $endpadding);
			my $now = POSIX::strftime('%Y.%m.%d-%H_%M_%S', localtime());

			print ".\n";

			# evaluation

			if ((($state eq 'scheduled') and ($now gt $paddedstart)) or
				(($state eq 'recording') and ($now gt $paddedend))) {
				print "moving ticket # $tid from state $state to next state ...";
				setTicketNextState($tid, $state, 'Recording Scheduler: ' .
					'the current time is over schedule for state $state.');
				print "\n";
			}
		}
	}
}

