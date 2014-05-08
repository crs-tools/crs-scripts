#!/usr/bin/perl -W

use strict;
require CRS::Fuse::VDV;
require C3TT::Client;
require boolean;

my $tracker = C3TT::Client->new();

my $ticket;
if (defined($ENV{'CRS_ROOM'})) {
	my $filter = {};
	$filter->{'Fahrplan.Room'} = $ENV{'CRS_ROOM'};
	$ticket = $tracker->assignNextUnassignedForState('recording', 'preparing', $filter);
} else {
	$ticket = $tracker->assignNextUnassignedForState('recording', 'preparing');
}

if (defined($ticket) && ref($ticket) ne 'boolean' && $ticket->{id} > 0) {
	my $tid = $ticket->{id};
	my $vid = $ticket->{fahrplan_id};
	print "got ticket # $tid for event $vid\n";

	my $props = $tracker->getTicketProperties($tid);
	my $fuse = CRS::Fuse::VDV->new($props);
	my $mounted = CRS::Fuse::isVIDmounted($vid);
	print "already mounted: $mounted\n";
	if ($mounted) {
		print " already mounted! unmounting... ";
		$fuse->doFuseUnmount($vid);
		print "done\n";
	}
	print "creating fuse mount for event # $vid\n";

	# fetch metadata

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

#	$room =~ s/[^0-9Gg]*//; # only the integer from room property
#	$room = lc($room);
	my $start = $startdate . '-' . $starttime; # put date and time together
	$endpadding = 45 * 60 if (!defined($endpadding)); # default padding is 45 min.
	my $startpadding = 15 * 60; # default startpadding is 15 min.
	my ($paddedstart, $paddedend, $paddedlength) = CRS::Fuse::getPaddedTimes($start, $duration, $startpadding, $endpadding);
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
	$props2{'Record.EndPadding'} = $endpadding;

	# now try to create the mount

	my $r = 1;
	if ($isRepaired) {
		$r = $fuse->doFuseRepairMount($vid, $room, $replacement);
	} else {
		$r = $fuse->doFuseMount($vid, $room, $paddedstart, $paddedlength);
	}

	if (defined($r) && $r) {
		$tracker->setTicketProperties($tid, \%props2); # when successful, do actually write back properties
		print "FUSE mount created successfully.\n";
		$tracker->setTicketDone($tid, 'Mount4cut: FUSE mount created successfully.');
           # indicate short sleep to wrapper script
           exit(100);
	} else {
		print "Mount4cut: ERROR: could not create FUSE mount!\n";
		$tracker->setTicketFailed($tid, 'Mount4cut: ERROR: could not create FUSE mount!');
	}
} else {
	print "no tickets currently recorded.\n";
}

