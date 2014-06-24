#!/usr/bin/perl -W

#require fusevdv;
require C3TT::Client;
require boolean;

my $tracker = C3TT::Client->new();
my $ticket;
if (defined($ENV{'CRS_ROOM'}) && $ENV{'CRS_ROOM'} ne '') {
        my $filter = {};
        $filter->{'Fahrplan.Room'} = $ENV{'CRS_ROOM'};
        $ticket = $tracker->assignNextUnassignedForState('encoding', 'postencoding', $filter);
} else {
        $ticket = $tracker->assignNextUnassignedForState('encoding', 'postencoding');
}

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
		# indicate short sleep to wrapper script
		exit(100);
	} else {
		$tracker->setTicketFailed($tid, 'Encoding postprocessor: scp to brisky failed');
	}
}
