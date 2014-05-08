#!/usr/bin/perl -W

require CRS::Fuse::VDV;
require C3TT::Client;
require boolean;

my $tracker = C3TT::Client->new();

my $ticket;
if (defined($ENV{'CRS_ROOM'})) {
        my $filter = {};
        $filter->{'Fahrplan.Room'} = $ENV{'CRS_ROOM'};
        $ticket = $tracker->assignNextUnassignedForState('recording', 'finalizing', $filter);
} else {
        $ticket = $tracker->assignNextUnassignedForState('recording', 'finalizing');
}

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for copying\n";
} else {
	my $tid = $ticket->{id};
	my $vid = $ticket->{fahrplan_id};
	print "got ticket # $tid for event $vid\n";

	my $props = $tracker->getTicketProperties($tid);
	my $replacement = $props->{'Record.SourceReplacement'};
	my $isRepaired = 0;
	$isRepaired = 1 if defined($replacement) && $replacement ne '';

	my $fuse = CRS::Fuse::VDV->new($props);
	my $ret = $fuse->checkCut($vid) + $isRepaired;
	if ($ret == 0) {
		print STDERR "cutting event # $vid / ticket # $tid incomplete!\n";
		$tracker->setTicketFailed($tid, 'CUTTING INCOMPLETE!');
		die ('CUTTING INCOMPLETE!');
	}
	# get necessary metadata from tracker
	my $starttime = $props->{'Record.Starttime'};

	# get metadata from fuse mount and store them in tracker
	my ($in, $out, $intime, $outtime) = $fuse->getCutmarks($vid, $starttime);
	my %props = (
		'Record.Cutin' => $in, 
		'Record.Cutout' => $out,
		'Record.Cutintime' => $intime,
		'Record.Cutouttime' => $outtime);
	$tracker->setTicketProperties($tid, \%props);
	$tracker->setTicketDone($tid, 'Cut postprocessor: cut completed, metadata written.');
	# indicate short sleep to wrapper script
	exit(100);

}



