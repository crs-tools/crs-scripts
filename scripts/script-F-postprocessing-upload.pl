#!/usr/bin/perl -W

use C3TT::Client;
use boolean;

my $tracker = C3TT::Client->new();
my $ticket = $tracker->assignNextUnassignedForState('encoding', 'postprocessing');

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for postprocessing\n";
} else {
	my $tid = $ticket->{id};
	print "postprocessing ticket # $tid\n";

	my $props = $tracker->getTicketProperties($tid);
	if (defined($props->{'Fahrplan.Recording.Optout'}) && $props->{'Fahrplan.Recording.Optout'} eq '1') {
		print "Ticket is opt-out!!\n\n";
		$tracker->setTicketFailed($tid, 'Recording has optout-flag!');
		exit(100);
	}

	my $srcfile = $props->{'Processing.Path.Output'} . "/" . $props->{'Fahrplan.ID'} . 
		"-" . $props->{'EncodingProfile.Slug'} . "." . $props->{'EncodingProfile.Extension'};
	print "checking $srcfile...";
	if (! -e $srcfile) {
		$tracker->setTicketFailed($tid, 'Encoding postprocessor: srcfile '.$srcfile.' not found!');
		die "file $srcfile not found\n";
	}
	print " OK\n";
	my $destfile = $props->{'Publishing.UploadTarget'} . '/' . $props->{'Fahrplan.ID'} . "-" . 
		$props->{'EncodingProfile.Slug'} . '.' . $props->{'EncodingProfile.Extension'};
	# support old property as fallback
	my $opts = $props->{'Publishing.UploadOptions'};
	$opts = $props->{'Processing.Postprocessing.Options'} unless defined ($opts);
	$opts = "" unless defined ($opts);
	print "$srcfile (in) -> $destfile (out) ...";
	my $cmd = "scp -B -p $opts '$srcfile' '$destfile'";
	my $return = system ($cmd);
	print " exit=$return\n";
	
	if ($return eq '0') {
		$tracker->setTicketDone($tid, 'Encoding postprocessor: scp completed.');
		# indicate short sleep to wrapper script
		exit(100);
	} else {
		$tracker->setTicketFailed($tid, "Encoding postprocessor: command '$cmd' failed!");
	}
}
