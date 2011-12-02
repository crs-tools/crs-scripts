#!/usr/bin/perl -W

require POSIX;
require trackerlib2;

# Call this script with hostname, secret and project slug as parameter!

my ($hostname, $secret, $project) = (shift, shift, shift);

initTracker('hostname' => $hostname, 'secret' => $secret, 'project' => $project);

my $tid = grabNextTicketForState('merging');

if (defined($tid) && $tid > 0) {
	print "releasing ticket # $tid\n";

	# fetch metadata

	my $count = getTicketProperty($tid, 'Release.Count');

	# preparation of new metadata

	my $now = POSIX::strftime('%Y.%m.%d_%H:%M:%S', localtime());
	$count = 0 unless defined($count) and $count =~ /^\d+$/;
	$count++;

	# releasing file

		# TODO upload essence file

	# write back to tracker

	setTicketProperty($tid, 'Release.Count', $count);
	setTicketProperty($tid, 'Release.Datetime', $now);
	releaseTicketToNextState($tid, 'released successfully');
}

