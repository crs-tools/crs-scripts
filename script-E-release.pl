#!/usr/bin/perl -W

require fusevdv;
require C3TT::Client;
require boolean;

# Call this script with secret and project slug as parameter!

my ($secret, $project) = (shift, shift);

if (!defined($project)) {
	# print usage
	print STDERR "Too few parameters given!\nUsage:\n\n";
	print STDERR "./script-.... <secret> <project slug>\n\n";
	exit 1;
}

my $tracker = C3TT::Client->new('http://tracker.28c3.fem-net.de/rpc', 'C3TT', $secret);
$tracker->setCurrentProject($project);
my $ticket = $tracker->assignNextUnassignedForState('releasing');

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for releasing\n";
} else {
	my $tid = $ticket->{id};
	print "releasing ticket # $tid\n";

	# fetch metadata

	my %props = $tracker->getTicketProperties($tid);

	# preparation of new metadata

	my $now = POSIX::strftime('%Y.%m.%d_%H:%M:%S', localtime());
	$count = 0 unless defined($count) and $count =~ /^\d+$/;
	$count++;

	# releasing file

		# TODO upload essence file

	# write back to tracker

	$tracker->setTicketProperty($tid, 'Release.Count', $count);
	$tracker->setTicketProperty($tid, 'Release.Datetime', $now);

	$tracker->setTicketDone($tid, 'Release Script: released successfully.');
}

