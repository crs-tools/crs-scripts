#!/usr/bin/perl -W

use CRS::Fuse::VDV;
use CRS::Fuse::TS;
use C3TT::Client;
use boolean;

my $tracker = C3TT::Client->new();
my $ticket = $tracker->assignNextUnassignedForState('recording', 'finalizing');

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for finalizing\n";
} else {
	my $tid = $ticket->{id};
	my $props = $tracker->getTicketProperties($tid);
	my $vid = $ticket->{fahrplan_id};
	$vid = $props->{'Fahrplan.ID'} if ($vid < 1);
	print "got ticket # $tid for event $vid\n";

	my $replacement = $props->{'Record.SourceReplacement'};
	my $isRepaired = 0;
	$isRepaired = 1 if ((defined($replacement) && $replacement ne '') 
		|| (defined($props->{'Fahrplan.VideoDownloadURL'} && $props->{'Fahrplan.VideoDownloadURL'} ne ''));
	my $container = $props->{'Record.Container'};
	$container = 'TS' unless defined($container);

	my $fuse;
	my $intropath;
	my $introduration = 0;

	if ($container eq 'DV') {
		$fuse = CRS::Fuse::VDV->new($props);
		$intropath = $fuse->getIntro('dv', $vid);
	} else {
		$fuse = CRS::Fuse::TS->new($props);
		$intropath = $fuse->getIntro('ts', $vid);
	}

	my $ret = $fuse->checkCut($vid) + $isRepaired;
	if ($ret == 0) {
		print STDERR "cutting event # $vid / ticket # $tid incomplete!\n";
		$tracker->setTicketFailed($tid, 'CUTTING INCOMPLETE! ' . $fuse->getCutError());
		die ('CUTTING INCOMPLETE!');
	}
	# check intro, gather duration
	if (defined($props->{'Processing.Path.Intros'}) && length $props->{'Processing.Path.Intros'} > 0) {
		if (!defined($intropath)) {
			$tracker->setTicketFailed($tid, 'INTRO MISSING!');
			die ('INTRO MISSING!');
		}
		my @ffprobe = qx ( ffprobe -i "$intropath" -sexagesimal -print_format flat -show_format );
		foreach (@ffprobe) {
			if ( $_ =~ /^format.duration="(.+)"/ ) {
				$introduration = $1;
				last;
			}
		}
	} else {
		undef $intropath;
	}

	my ($in, $out, $inseconds, $outseconds) = (0, undef, 0, undef);
	if ($isRepaired == 0 || $container eq 'DV') {
		# get necessary metadata from tracker
		my $starttime = $props->{'Record.Starttime'};

		# get metadata from fuse mount and store them in tracker
		($in, $out, $inseconds, $outseconds) = $fuse->getCutmarks($vid, $starttime);
	} else {
		$uncutpath = $fuse->getMountPath($vid) . '/uncut.ts';
		my @ffprobe = qx ( ffprobe -i "$uncutpath" -print_format flat -show_format );
		foreach (@ffprobe) {
			if ( $_ =~ /^format.duration="(.+)"/ ) {
				$outseconds = $1;
				last;
			}
		}
	}

	my $diffseconds;
	$diffseconds = $outseconds - $inseconds if (defined($outseconds) && defined($inseconds));
	$inseconds =~ s/\.0+$// if defined($inseconds);
	$diffseconds =~ s/\.0+$// if defined($diffseconds);
	$outseconds =~ s/\.0+$// if defined($outseconds);
	$inseconds =~ s/0+$// if ($inseconds =~ /\.[0-9]+/);
	$diffseconds =~ s/0+$// if ($diffseconds =~ /\.[0-9]+/);
	$outseconds =~ s/0+$// if ($outseconds =~ /\.[0-9]+/);
	my %props = (
		'Record.Cutin' => $in, 
		'Record.Cutinseconds' => $inseconds,
		'Record.Cutdiffseconds' => $diffseconds);
	$props{'Record.Cutout'} = $out if (defined($out));
	$props{'Record.Cutoutseconds'} = $outseconds if (defined($outseconds));

	$props{'Processing.Duration.Intro'} = $introduration;

	$tracker->setTicketProperties($tid, \%props);
	$tracker->setTicketDone($tid, 'Cut postprocessor: cut completed, metadata written.');
	# indicate short sleep to wrapper script
	exit(100);
}



