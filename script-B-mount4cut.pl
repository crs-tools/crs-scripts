#!/usr/bin/perl -W

use Data::Dumper;
require trackerlib2;
require fusevdv;

# Call this script with hostname, secret and project slug as parameter!

my ($hostname, $secret, $project) = (shift, shift, shift);

initTracker('hostname' => $hostname, 'secret' => $secret, 'project' => $project);
my $tid = grabNextTicketForState('merging');

if (defined($tid) && $tid > 0) {
	print "got ticket # $tid\n";
	my $vid = getVIDfromTicketID($tid);
	print "event # is $vid\n";
	my $mounted = isVIDmounted($vid);
	print "already mounted: $mounted\n";
	if ($mounted) {
		print " already mounted! unmounting... ";
		doFuseUnmount($vid);
		print "done\n";
	}
	print "creating fuse mount for event # $vid\n";

	# fetch metadata

	my %props = getTicketProperties($tid);
	my $room = $props{'Fahrplan.Room'};
	my $startdate = $props{'Fahrplan.Date'};
	my $starttime = $props{'Fahrplan.Start'};
	my $duration = $props{'Fahrplan.Duration'};

	# check minimal metadata

	if (!defined($room) || !defined($startdate) 
		|| !defined($duration) || !defined($starttime)) {
		print STDERR "NOT ENOUGH METADATA!\n";
		releaseTicketAsBroken($tid);
		die("NOT ENOUGH METADATA!\n");
	}
	my $endpadding = $props{'Record.EndPadding'};

	# transformation of metadata

	$room =~ s/[^0-9]*//; # only the integer from room property
	my $start = $startdate . '-' . $starttime; # put date and time together
	$endpadding = 45 * 60 if (!defined($endpadding)); # default padding is 45 min.
	$startpadding = 5 * 60; # default startpadding is 5 min.
	my ($paddedstart, $paddedend, $paddedlength) = getPaddedTimes($start, $duration, $startpadding, $endpadding);
	my $paddedstart2 = $paddedstart;
	$paddedstart2 =~ s/[\._-]/-/g; # different syntax for Record.Starttime
	my $paddedend2 = $paddedend;
	$paddedend2 =~ s/[\._-]/-/g; # different syntax for Record.Stoptime

	# prepare attributes for writeback

	%props = ();
	$props{'Record.Room'} = $room;
	$props{'Record.Starttime'} = $paddedstart2;
	$props{'Record.Stoptime'} = $paddedend2;
	$props{'Record.DurationSeconds'} = $paddedlength;
	$props{'Record.DurationFrames'} = $paddedlength * 25;

	# now try creating the mount

	my $r = doFuseMount($vid, $room, $paddedstart, $paddedlength);
	if (defined($r) && $r) {
		setTicketProperties($tid, \%props); # when successful, do actually write back properties
		releaseTicketToNextState($tid, 'Mount4cut: FUSE mount created successfully.');
	} else {
		releaseTicketAsBroken($tid, 'Mount4cut: ERROR: could not create FUSE mount!');
	}
}

