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

initTracker('hostname' => $hostname, 'secret' => $secret, 'project' => $project);

foreach ('scheduled', 'recording') {
	my $state = $_;
	my @tids = getAllUnassignedTicketsInState($state);

	if (!(@tids)) {
		print "no tickets $state.\n";
		next;
	} 
	foreach (@tids) {
		my $tid = $_;
		if (defined($tid) && $tid > 0) {
			print "inspecting ticket # $tid\n";

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

			my $start = $startdate . '-' . $starttime; # put date and time together
			my ($paddedstart, $paddedend, undef) = getPaddedTimes($start, $duration, $startpadding, $endpadding);
			my $now = POSIX::strftime('%Y.%m.%d-%H_%M_%S', localtime());

			# evaluation

			if ((($state eq 'scheduled') and ($now gt $paddedstart)) or
				(($state eq 'recording') and ($now gt $paddedend))) {
				print "moving ticket # $tid\n";
				setTicketNextState($tid);
			}
		}
	}
}

