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
my $ticket = $tracker->assignNextUnassignedForState('postprocessing');

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for postprocessing\n";
} else {
	my $tid = $ticket->{id};
	print "postprocessing ticket # $tid\n";

	# fetch metadata

	my %props = $tracker->getTicketProperties($tid);

		# TODO create torrent file, create checksums, backup (?, c3ftp?)

	# write metadata back to tracker (?)

	my %props2 = (
		'foo' => 'bar', 
		'food' => 'obstsalat');
	$tracker->setTicketProperties($tid, \%props2);
	$tracker->setTicketDone($tid, 'Encoding postprocessor: completed, metadata written.');
}


