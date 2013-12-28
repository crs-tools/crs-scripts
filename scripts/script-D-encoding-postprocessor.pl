#!/usr/bin/perl -W

#require fusevdv;
require C3TT::Client;
require boolean;

# Call this script with secret and project slug as parameter!

my ($secret, $token) = ($ENV{'CRS_SECRET'}, $ENV{'CRS_TOKEN'});

if (!defined($token)) {
	# print usage
	print STDERR "Too few parameters given!\nUsage:\n\n";
	print STDERR "./script-.... <secret> <token>\n\n";
	exit 1;
}

my $tracker = C3TT::Client->new('https://tracker.fem.tu-ilmenau.de/rpc', $token, $secret);
my $ticket = $tracker->assignNextUnassignedForState('encoding', 'postprocessing');

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
	my $srcfile = $props->{'Processing.Path.Prerelease'} . "/" . $props->{'Fahrplan.ID'} . 
		"-" . $props->{'EncodingProfile.Slug'} . "." . $props->{'EncodingProfile.Extension'};
	print "checking $srcfile\n";
	if (! -f $srcfile) {
		$tracker->setTicketFailed($tid, 'Encoding postprocessor: srcfile '.$srcfile.' not found!');
	}
	my $destbasename = $props->{'Processing.Path.Release'} . '/' . $props->{'Fahrplan.ID'};
	my $destfile = $destbasename . "-" . $props->{'EncodingProfile.Slug'} . '.' . $props->{'EncodingProfile.Extension'};
	my $return = system ("scp -i /root/.ssh/id_rsa $srcfile fem\@10.73.0.11:/opt/crs/encoded/ ");
	#my $return = system ("cp $srcfile $destfile");
	print "$srcfile (in) -> $destfile (out) - exit=$return\n";
	
	# generate thumbnails
	my $offset = $props->{'Record.DurationSeconds'}/2;
	print "generating thumbnails at $offset seconds\n";
#	my $return2 = system("ffmpeg -ss $offset -i $srcfile -y -f image2 -vframes 1 -s 768x432 $destbasename.jpg");
#	$return2 = system("ffmpeg -ss $offset -i $srcfile -y -f image2 -vframes 1 -s 334x188 $destbasename-thumb.jpg");

	# write metadata back to tracker (?)

	if ($return eq '0') {
		$tracker->setTicketDone($tid, 'Encoding postprocessor: scp to brisky completed.');
	} else {
		$tracker->setTicketFailed($tid, 'Encoding postprocessor: scp to brisky failed');
	}
}
