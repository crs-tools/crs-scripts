#!/usr/bin/perl -W

use strict;
use CRS::Fuse::VDV;
use CRS::Fuse::TS;
use CRS::Tracker::Client;
use boolean;

my ($secret, $token) = ($ENV{'CRS_SECRET'}, $ENV{'CRS_TOKEN'});

if (!defined($token)) {
	# print usage
	print STDERR "Too few parameters given!\n";
	print STDERR "Give secret and token via environment, please\n\n";
	exit 1;
}

my $tracker = CRS::Tracker::Client->new();

my $ticket = $tracker->assignNextUnassignedForState('recording', 'preparing');

if (defined($ticket) && ref($ticket) ne 'boolean' && $ticket->{id} > 0) {
	prepareTicket($ticket);
} else {
	print "no tickets currently recorded.\n";
	my $tickets = $tracker->getAssignedForState('recording', 'preparing');
	if (!($tickets) || 0 == scalar(@$tickets)) {
		print "no tickets currently preparing.\n";
		exit;
	}
	foreach (@$tickets) {
		my $ticket = $_;
		print "revisiting files of ticket #" . $ticket->{id} . "\n";
		prepareTicket($ticket);
	}
}

sub prepareTicket {
	my $ticket = shift;
	my $tid = $ticket->{id};
	my $props = $tracker->getTicketProperties($tid);
	my $vid = $ticket->{fahrplan_id};
	$vid = $props->{'Fahrplan.ID'} if ($vid < 1);
	print "got ticket # $tid for event $vid\n";

	my $container = $props->{'Record.Container'};

	my $fuse;
	if (defined($container) and $container eq 'DV') {
		$fuse = CRS::Fuse::VDV->new($props);
	} else {
		$fuse = CRS::Fuse::TS->new($props);
	}

	my ($in, $out, $inseconds, $outseconds) = ();
	print "checking if mounted... ";
	my $mounted = $fuse->isVIDmounted($vid);
	if ($mounted) {
		print "already mounted! saving cutmarks ... ";
		if ($fuse->checkCut($vid)) {
			($in, $out, $inseconds, $outseconds) = $fuse->getCutmarks($vid);
		}
		print " got cutmarks: IN $in OUT $out, unmounting... ";
		$fuse->doFuseUnmount($vid);
		print "done\n";
	} else {
		print "not currently mounted.\n";
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

	# prepare possible restoration of cutmarks
	$in = $props->{'Record.Cutin'} unless defined($in);
	$out = $props->{'Record.Cutout'} unless defined($out);

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
	$endpadding = 15 * 60 if (!defined($endpadding)); # default padding is 15 min.
	$startpadding = 15 * 60 unless defined($startpadding); # default startpadding is 15 min.
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
		# restore cutmarks if available
		$fuse->setCutmarks($in, $out) if (defined($in) or defined($out));
		$tracker->setTicketDone($tid, "Mount4cut: FUSE mount created successfully.\n" . $cmd . "\n" . $error);
		# indicate short sleep to wrapper script
		exit(100);
	} elsif ($error eq 'files missing') {
		print "Mount4cut: WARNING: could not create FUSE mount because of missing files. Leaving ticket in preparing state\n";
		sleep 1;
	} else {
		print "Mount4cut: ERROR: could not create FUSE mount!\n";
		$tracker->setTicketFailed($tid, "Mount4cut: ERROR: could not create FUSE mount!\n" . $cmd . "\n" . $error);
	}
}

