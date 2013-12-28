#!/usr/bin/perl -W

require C3TT::Client;
require boolean;

# Call this script with secret and project slug as parameter!

my ($secret, $project) = ($ENV{'CRS_SECRET'}, $ENV{'CRS_SLUG'});


if (!defined($project)) {
	# print usage
	print STDERR "Too few parameters given!\nUsage:\n\n";
	print STDERR "./script-.... <secret> <project slug>\n\n";
	exit 1;
}

my $tracker = C3TT::Client->new('http://tracker.fem.tu-ilmenau.de/rpc', 'C3TT', $secret, 'postproc');
$tracker->setCurrentProject($project);
my $ticket = $tracker->assignNextUnassignedForState('postprocessing');

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for postprocessing\n";
} else {
	my $tid = $ticket->{id};
	print "postprocessing ticket # $tid\n";

	# fetch metadata

	my $props = $tracker->getTicketProperties($tid);

	my $srcfile = $props->{'Processing.Path.Prerelease'} . "/" . $props->{'Encoding.Basename'} . "." . $props->{'EncodingProfile.Extension'};

	if (! -f $srcfile) {
		$srcfile = $props->{'Processing.Path.Prerelease'} . "/" . $props->{'EncodingProfile.Basename'} . "." . $props->{'EncodingProfile.Extension'};
		if (! -f $srcfile) {
			$tracker->setTicketFailed($tid, 'Encoding postprocessor: srcfile '.$srcfile.' not found!');
			exit 1;
		}
	}
	#my $return = system ("scp -i /root/.ssh/id_rsa $srcfile black_pearl\@chief-mirror.fem-net.de:/mnt/data/release/ ");
	my $return = 0;

	print "$srcfile \n$return\n";

	# write metadata back to tracker (?)

	$tracker->setTicketDone($tid, 'Encoding postprocessor: file check completed.');
}

