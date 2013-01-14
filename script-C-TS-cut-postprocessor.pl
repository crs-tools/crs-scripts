#!/usr/bin/perl -W

require fusets;
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

my $tracker = C3TT::Client->new('http://tracker.fem.tu-ilmenau.de/rpc', 'C3TT', $secret, 'cut-post');
$tracker->setCurrentProject($project);
my $ticket = $tracker->assignNextUnassignedForState('copying');

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for copying\n";
} else {
	my $tid = $ticket->{id};
	my $vid = $ticket->{fahrplan_id};
	print "got ticket # $tid for event $vid\n";

	my $props = $tracker->getTicketProperties($tid, 'Record.*');
	my $replacement = $props->{'Record.SourceReplacement'};
	my $isRepaired = 0;
	$isRepaired = 1 if defined($replacement) && $replacement ne '';

	my $ret = checkCut($vid) + $isRepaired;
	if ($ret == 0) {
		print STDERR "cutting event # $vid / ticket # $tid incomplete!\n";
		$tracker->setTicketFailed($tid, 'CUTTING INCOMPLETE!');
		die ('CUTTING INCOMPLETE!');
	}
	# get necessary metadata from tracker
	my $starttime = $props->{'Record.Starttime'};

	# get metadata from fuse mount and store them in tracker
	my ($in, $out, $intime, $outtime, $inseconds, $outseconds) = getCutmarks($vid, $starttime);
	my $diffseconds = $outseconds - $inseconds;
	my %props = (
		'Record.Cutin' => $in, 
		'Record.Cutout' => $out,
		'Record.Cutintime' => $intime,
		'Record.Cutouttime' => $outtime,
		'Record.Cutinseconds' => $inseconds,
		'Record.Cutdiffseconds' => $diffseconds,
		'Record.Cutoutseconds' => $outseconds);
	$tracker->setTicketProperties($tid, \%props);
	$tracker->setTicketDone($tid, 'Cut postprocessor: cut completed, metadata written.');
}



