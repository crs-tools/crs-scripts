#!/usr/bin/perl -W

require CRS::Fuse::TS;
require C3TT::Client;
require boolean;
use Data::Dumper;

# Call this script with secret and project slug as parameter!

my ($secret, $token) = ($ENV{'CRS_SECRET'}, $ENV{'CRS_TOKEN'});

if (!defined($token)) {
	# print usage
	print STDERR "Too few parameters given!\nUsage:\n\n";
	print STDERR "./script-.... <secret> <token>\n\n";
	exit 1;
}

my $tracker = C3TT::Client->new('http://tracker.fem-net.de/rpc', $token, $secret);                                                                    
my $ticket = $tracker->assignNextUnassignedForState('recording','finalizing');

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for finalizing\n";
} else {
	my $tid = $ticket->{id};
	my $vid = $ticket->{fahrplan_id};
	print "got ticket # $tid for event $vid\n";

	my $props = $tracker->getTicketProperties($tid);
	my $replacement = $props->{'Record.SourceReplacement'};
	my $isRepaired = 0;
	$isRepaired = 1 if defined($replacement) && $replacement ne '';

	my $fuse = CRS::Fuse::TS->new($props);

	my $ret = $fuse->checkCut($vid) + $isRepaired;
	if ($ret == 0) {
		print STDERR "cutting event # $vid / ticket # $tid incomplete!\n";
		$tracker->setTicketFailed($tid, 'CUTTING INCOMPLETE!');
		die ('CUTTING INCOMPLETE!');
	}
	# get necessary metadata from tracker
	my $starttime = $props->{'Record.Starttime'};

	# get metadata from fuse mount and store them in tracker
	my ($in, $out, $intime, $outtime, $inseconds, $outseconds) = $fuse->getCutmarks($vid, $starttime);
	my $diffseconds = $outseconds - $inseconds;
#	$in =~ s/0+$//;
#	$out =~ s/0+$//;
#	$intime =~ s/0+$//;
#	$outtime =~ s/0+$//;
	$inseconds =~ s/\.0+$//;
	$diffseconds =~ s/\.0+$//;
	$outseconds =~ s/\.0+$//;
	$inseconds =~ s/0+$// if ($inseconds =~ /\.[0-9]+/);
	$diffseconds =~ s/0+$// if ($diffseconds =~ /\.[0-9]+/);
	$outseconds =~ s/0+$// if ($outseconds =~ /\.[0-9]+/);
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
	# indicate short sleep to wrapper script
	exit(100);
}



