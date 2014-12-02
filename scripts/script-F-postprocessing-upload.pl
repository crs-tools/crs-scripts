#!/usr/bin/perl -W

require C3TT::Client;
require boolean;

my $tracker = C3TT::Client->new();
my $ticket;
if (defined($ENV{'CRS_ROOM'}) && $ENV{'CRS_ROOM'} ne '') {
        my $filter = {};
        $filter->{'Fahrplan.Room'} = $ENV{'CRS_ROOM'};
	if (defined($ENV{'CRS_PROFILE'}) && $ENV{'CRS_PROFILE'} ne '') {
        	$filter->{'EncodingProfile.Slug'} = $ENV{'CRS_PROFILE'};
	}
        $ticket = $tracker->assignNextUnassignedForState('encoding', 'postprocessing', $filter);
} else {
        $ticket = $tracker->assignNextUnassignedForState('encoding', 'postprocessing');
}

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for postprocessing\n";
} else {
	my $tid = $ticket->{id};
	print "postprocessing ticket # $tid\n";

	my $props = $tracker->getTicketProperties($tid);
	my $srcfile = $props->{'Processing.Path.Output'} . "/" . $props->{'Fahrplan.ID'} . 
		"-" . $props->{'EncodingProfile.Slug'} . "." . $props->{'EncodingProfile.Extension'};
	print "checking $srcfile...";
	if (! -f $srcfile) {
		$tracker->setTicketFailed($tid, 'Encoding postprocessor: srcfile '.$srcfile.' not found!');
	}
	print " OK\n";
	my $destfile = $props->{'Processing.Path.PreRelease'} . '/' . $props->{'Fahrplan.ID'} . "-" . 
		$props->{'EncodingProfile.Slug'} . '.' . $props->{'EncodingProfile.Extension'};
	my $opts = $props->{'Processing.Postprocessing.Options'};
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
