#!/usr/bin/perl -W

use Data::Dumper;
require trackerlib2;
require fusevdv;

# Call this script with hostname, secret and project slug as parameter!

my ($hostname, $secret, $project) = (shift, shift, shift);

initTracker('hostname' => $hostname, 'secret' => $secret, 'project' => $project);
my $tid = grabNextTicketInState('cut');

if (defined($tid) && $tid > 0) {
	print "got ticket # $tid\n";
	my $vid = getVIDfromTicketID($tid);
	print "event # is $vid\n";

	my $ret = checkCut($vid);
#	if ($ret == 0) {
#		print STDERR "cutting event # $vid / ticket # $tid incomplete!\n";
#		releaseTicketAsBroken($tid, 'CUTTING INCOMPLETE!');
#		die ('CUTTING INCOMPLETE!');
#	}
	# get necessary metadata from tracker
	my $starttime = getTicketProperty($tid, 'Record.Starttime');
$starttime = '2011-12-28-00:15';
	# get metadata from fuse mount and store them in tracker
	my ($in, $out, $intime, $outtime) = getCutmarks($vid, $starttime);
	my %props = (
		'Record.Cutin' => $in, 
		'Record.Cutout' => $out,
		'Record.Cutintime' => $intime,
		'Record.Cutouttime' => $outtime);
	setTicketProperties($tid, \%props);
	releaseTicketToNextState($tid, 'cut completed');
}



