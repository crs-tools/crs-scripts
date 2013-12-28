#!/usr/bin/perl -W

use strict;
require CRS::Fuse::TS;
require C3TT::Client;
require boolean;

# Call this script with secret and project slug as parameter!

my ($secret, $token) = ($ENV{'CRS_SECRET'}, $ENV{'CRS_TOKEN'});

if (!defined($token)) {
	# print usage
	print STDERR "Too few parameters given!\nUsage:\n\n";
	print STDERR "./script-.... <secret> <token>\n\n";
	exit 1;
}

my $tracker = C3TT::Client->new('https://tracker.fem.tu-ilmenau.de/rpc', $token, $secret);
#$tracker->setCurrentProject($project);
my $ticket = $tracker->assignNextUnassignedForState('recording', 'preparing');

if (defined($ticket) && ref($ticket) ne 'boolean' && $ticket->{id} > 0) {
	my $tid = $ticket->{id};
	my $vid = $ticket->{fahrplan_id};
	my $props = $tracker->getTicketProperties($tid);
	$vid = $props->{'Fahrplan.ID'} if ($vid < 1);
	print "got ticket # $tid for event $vid\n";
	
	my $fuse = CRS::Fuse::TS->new($props);
	
	my $mounted = $fuse->isVIDmounted($vid);
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
	my $startpadding = $props->{'Record.StartPadding'};
	my $endpadding = $props->{'Record.EndPadding'};

	# transformation of metadata
	$room =~ s/[^0-9]*//; # only the integer from room property
	my $start = $startdate . '-' . $starttime; # put date and time together
	$endpadding = 5 * 60 if (!defined($endpadding)); # default padding is 15 min.
	$startpadding = 2 * 60 unless defined($startpadding); # default startpadding is 5 min.
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
	if ($isRepaired == 1) {
		print "Creating repair mount...\n";
		$r = $fuse->doFuseRepairMount($vid, $replacement);
	} else {
		if ($paddedstart =~ /^([0-9]{4}).([0-9]{2}).([0-9]{2}).([0-9]{2}).([0-9]{2}).([0-9]{2})/) { # different syntax for TS-Capture
			$paddedstart = "$1-$2-$3_$4-$5-$6";
		}
		$r = $fuse->doFuseMount($vid, $room, $paddedstart, $paddedlength);
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

