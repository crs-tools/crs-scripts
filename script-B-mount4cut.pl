#!/usr/bin/perl -W

use strict;
require fusevdv;
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

my $tracker = C3TT::Client->new('http://tracker.28c3.fem-net.de/rpc', 'C3TT', $secret);
$tracker->setCurrentProject($project);
my $ticket = $tracker->assignNextUnassignedForState('merging');

if (defined($ticket) && ref($ticket) ne 'boolean' && $ticket->{id} > 0) {
	my $tid = $ticket->{id};
	my $vid = $ticket->{fahrplan_id};
	print "got ticket # $tid for event $vid\n";
	my $mounted = isVIDmounted($vid);
	print "already mounted: $mounted\n";
	if ($mounted) {
		print " already mounted! unmounting... ";
		doFuseUnmount($vid);
		print "done\n";
	}
	print "creating fuse mount for event # $vid\n";

	# fetch metadata

	my $props = $tracker->getTicketProperties($tid);
	my $room = $props->{'Fahrplan.Room'};
	my $startdate = $props->{'Fahrplan.Date'};
	my $starttime = $props->{'Fahrplan.Start'};
	my $duration = $props->{'Fahrplan.Duration'};
	my $replacement = $props->{'Record.SourceReplacement'};
	my $isRepaired = 0;
	$isRepaired = 1 if defined($replacement) && $replacement ne '';

	# check minimal metadata

	if (!defined($room) || !defined($startdate) 
		|| !defined($duration) || !defined($starttime)) {
		print STDERR "NOT ENOUGH METADATA!\n";
		$tracker->setTicketFailed($tid, 'Not enough metadata');
		die("NOT ENOUGH METADATA!\n");
	}
	my $endpadding = $props->{'Record.EndPadding'};

	# transformation of metadata

	$room =~ s/[^0-9]*//; # only the integer from room property
	my $start = $startdate . '-' . $starttime; # put date and time together
	$endpadding = 45 * 60 if (!defined($endpadding)); # default padding is 45 min.
	my $startpadding = 5 * 60; # default startpadding is 5 min.
	my ($paddedstart, $paddedend, $paddedlength) = getPaddedTimes($start, $duration, $startpadding, $endpadding);
	my $paddedstart2 = $paddedstart;
	$paddedstart2 =~ s/[\._-]/-/g; # different syntax for Record.Starttime
	my $paddedend2 = $paddedend;
	$paddedend2 =~ s/[\._-]/-/g; # different syntax for Record.Stoptime

	# prepare attributes for writeback

	my %props2 = ();
	$props2{'Record.Room'} = $room;
	$props2{'Record.Starttime'} = $paddedstart2;
	$props2{'Record.Stoptime'} = $paddedend2;
	$props2{'Record.DurationSeconds'} = $paddedlength;
	$props2{'Record.DurationFrames'} = $paddedlength * 25;

	# now try to create the mount

	my $r = 1;
	if ($isRepaired) {
		$r = doFuseRepairMount($vid, $room, $replacement);
	} else {
		$r = doFuseMount($vid, $room, $paddedstart, $paddedlength);
	}

	if (defined($r) && $r) {
		$tracker->setTicketProperties($tid, \%props2); # when successful, do actually write back properties
		print "FUSE mount created successfully.\n";
		$tracker->setTicketDone($tid, 'Mount4cut: FUSE mount created successfully.');
	} else {
		print "Mount4cut: ERROR: could not create FUSE mount!\n";
		$tracker->setTicketFailed($tid, 'Mount4cut: ERROR: could not create FUSE mount!');
	}
} else {
	print "no tickets currently recorded.\n";
}

