#!/usr/bin/perl -W

require POSIX;
require trackerlib2;

# Call this script with hostname, secret and project slug as parameter!

my ($hostname, $secret, $project) = (shift, shift, shift);

initTracker('hostname' => $hostname, 'secret' => $secret, 'project' => $project);

my $tid = grabNextTicketForState('postprocessing');

if (defined($tid) && $tid > 0) {
	print "postprocessing ticket # $tid\n";

	# fetch metadata

	my %props = getTicketProperties($tid);

	# postprocessing file

		# TODO create torrent file, create checksums, backup (?, c3ftp?)

	# write back to tracker

	releaseTicketToNextState($tid, 'postprocessed successfully');
}

