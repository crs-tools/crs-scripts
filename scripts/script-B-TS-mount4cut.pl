#!/usr/bin/perl -W

use strict;
use CRS::Fuse::TS;
use C3TT::Client;
use boolean;

# Call this script with secret and project slug as parameter!

my ($secret, $token) = ($ENV{'CRS_SECRET'}, $ENV{'CRS_TOKEN'});

if (!defined($token)) {
	# print usage
	print STDERR "Too few parameters given!\nUsage:\n\n";
	print STDERR "./script-.... <secret> <token>\n\n";
	exit 1;
}

my $tracker = C3TT::Client->new();
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
		$tracker->setTicketFailed($tid, 
			"Not enough metadata!\n".
			"Make sure that the ticket has following attributes:\n".
			"-Fahrplan.Room\n-Fahrplan.Date\n-Fahrplan.Duration\n-Fahrplan.Start");
		die("NOT ENOUGH METADATA!\n");
	}
	my $startpadding = $props->{'Record.StartPadding'};
	my $endpadding = $props->{'Record.EndPadding'};

	# transformation of metadata

	my $start = $startdate . '-' . $starttime; # put date and time together
	$endpadding = 5 * 60 if (!defined($endpadding)); # default padding is 5 min.
	$startpadding = 5 * 60 unless defined($startpadding); # default startpadding is 5 min.
	my ($paddedstart, $paddedlength) = CRS::Fuse::getPaddedTimes($start, $duration, $startpadding, $endpadding);

	# now try to create the mount

	my ($r, $error, $cmd);
	if ($isRepaired) {
		print "Creating repair mount with source '$replacement'\n";
		($r, $error, $cmd) = $fuse->doFuseRepairMount($vid, $replacement);
	} else {
		if (defined($room)) {
			$room =~ s/\ +//g;
			$room = lc($room);
		}
		($r, $error, $cmd) = $fuse->doFuseMount($vid, $room, $paddedstart, $paddedlength);
	}

	# prepare attributes for writeback

	my %props2 = ();
	$props2{'Record.Room'} = $room if (defined($room));
	$props2{'Record.DurationSeconds'} = $paddedlength;
	$props2{'Record.DurationFrames'} = $paddedlength * 25;
	$props2{'Record.EndPadding'} = $endpadding;
	$props2{'Record.MountCmd'} = $cmd;

	if (defined($r) && $r) {
		$tracker->setTicketProperties($tid, \%props2); # when successful, do actually write back properties
		print "FUSE mount created successfully.\n";
		$tracker->setTicketDone($tid, "Mount4cut: FUSE mount created successfully.\n" . $cmd . "\n" . $error);
		# indicate short sleep to wrapper script
		exit(100);
	} else {
		print "Mount4cut: ERROR: could not create FUSE mount!\n";
		$tracker->setTicketFailed($tid, "Mount4cut: ERROR: could not create FUSE mount!\n" . $cmd . "\n" . $error);
	}
} else {
	print "no tickets currently recorded.\n";
}

