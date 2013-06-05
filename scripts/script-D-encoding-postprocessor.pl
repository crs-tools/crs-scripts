#!/usr/bin/perl -W

#require fusevdv;
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
	my $basename = $props->{'EncodingProfile.Basename'};
	my $slug = '';
	if ($basename =~ /_([^_]+$)/) {
		$slug = $1;
	}
	my $srcfile = $props->{'Processing.Path.Prerelease'} . "/" . $props->{'Fahrplan.ID'} . "-" . $slug . "." . $props->{'EncodingProfile.Extension'};
	print "checking $srcfile\n";
	if (! -f $srcfile) {
		$srcfile = $props->{'Processing.Path.Prerelease'} . "/" . $props->{'Encoding.Basename'} . "." . $props->{'EncodingProfile.Extension'};
		if (! -f $srcfile) {
			$tracker->setTicketFailed($tid, 'Encoding postprocessor: srcfile '.$srcfile.' not found!');
			exit 1;
		}
	}
	my $destbasename = $props->{'Processing.Path.Release'} . '/' . $props->{'Fahrplan.Slug'};
	my $destfile = $destbasename . "." . $props->{'EncodingProfile.Extension'};
#	my $return = system ("scp -i /root/.ssh/id_rsa $srcfile ecki\@chief-mirror.fem-net.de:~/release/ ");

	my $return = system ("cp $srcfile $destfile");
	print "$srcfile (in) -> $destfile (out) - exit=$return\n";
	
	# generate thumbnails
	my $offset = $props->{'Record.DurationSeconds'}/2;
	print "generating thumbnails at $offset seconds\n";
	my $return2 = system("ffmpeg -ss $offset -i $srcfile -y -f image2 -vframes 1 -s 768x432 $destbasename.jpg");
	$return2 = system("ffmpeg -ss $offset -i $srcfile -y -f image2 -vframes 1 -s 334x188 $destbasename-thumb.jpg");

	# write metadata back to tracker (?)

	if ($return eq '0') {
		$tracker->setTicketDone($tid, 'Encoding postprocessor: copy to chief-mirror completed.');
	} else {
		$tracker->setTicketFailed($tid, 'Encoding postprocessor: scp to chief-mirror failed');
	}
}
