#!/usr/bin/perl -W

use CRS::Fuse::VDV;
use CRS::Fuse::TS;
use CRS::Tracker::Client;
use CRS::Paths;
use CRS::Media;
use boolean;
use bignum;

my $tracker = CRS::Tracker::Client->new();
my $ticket = $tracker->assignNextUnassignedForState('recording', 'finalizing');

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for finalizing\n";
} else {
	my $tid = $ticket->{id};
	my $props = $tracker->getTicketProperties($tid);
	my $vid = $ticket->{fahrplan_id};
	my $paths = CRS::Paths->new($props);
	$vid = $props->{'Fahrplan.ID'} if ($vid < 1);
	print "got ticket # $tid for event $vid\n";

	my $replacement = $props->{'Record.SourceReplacement'};
	my $isRepaired = 0;
	$isRepaired = 1 if ((defined($replacement) && $replacement ne '') 
		|| (defined($props->{'Fahrplan.VideoDownloadURL'} && $props->{'Fahrplan.VideoDownloadURL'} ne '')));
	my $container = $props->{'Record.Container'};
	$container = 'TS' unless defined($container);
	$preferredIntroSuffix = lc($container);

	my $fuse;
	if (defined($container) and $container eq 'DV') {
		$fuse = CRS::Fuse::VDV->new($props);
	} else {
		$fuse = CRS::Fuse::TS->new($props);
	}

	my $intropath = my $orig_intropath = $props->{'Processing.File.Intro'};
	$intropath //= $fuse->getIntro($preferredIntroSuffix, $vid);
	$orig_intropath //= '';
	my $outropath = my $orig_outropath = $props->{'Processing.File.Outro'};
	$outropath //= $fuse->getOutro($preferredIntroSuffix, $vid);
	$orig_outropath //= '';

	my $introduration = 0;
	my $fail = 0;
	my $cutmarksvalid = 0;
	my $failreason = '';

	my $ret = $fuse->checkCut($vid) + $isRepaired;
	if ($ret == 0) {
		print STDERR "cutting event # $vid / ticket # $tid incomplete!\n";
		$failreason = 'CUTTING INCOMPLETE! ' . $fuse->getCutError(). ' ';
		$fail = 1;
	} else {
		$cutmarksvalid = 1;
	}
	# check intro, gather duration
	my $introconfigpath = $paths->getPath('Intros');
	if (defined($introconfigpath) && length $introconfigpath > 0) {
		if (!defined($intropath) || !-f $intropath) {
			$failreason .= 'INTRO MISSING!';
			$fail = 1;
		} else {
			$introduration = CRS::Media::getDuration($intropath, 0);
		}
	} else {
		# it might be that an Intro was defined globally via property without the search path scheme
		if (defined($intropath) && length $intropath > 0 && -f $intropath) {
			$introduration = CRS::Media::getDuration($intropath, 0);
		}
	}
	if ($introduration == 0) {
		undef $intropath;
		undef $introduration;
	}

	# check outro
	my $outroconfigpath = $paths->getPath('Outro');
	if (defined($outroconfigpath) && length $outroconfigpath > 0) {
		if (!defined($outropath) || !-f $outropath) {
			$failreason = 'OUTRO MISSING!';
			$fail = 1;
		}
	} else {
		# it might be that an Outro was defined globally via property without the search path scheme
		if (defined($outropath) && length $outropath > 0) {
			if (! -f $outropath) {
				$failreason = 'OUTRO MISSING!';
				$fail = 1;
			}
		} else {
			undef $outropath;
		}
	}

	my ($in, $out, $inseconds, $outseconds) = (0, undef, 0, undef);
	if ($isRepaired == 0 || $container eq 'DV') {
		# get necessary metadata from tracker
		my $starttime = $props->{'Record.Starttime'};

		# get metadata from fuse mount and store them in tracker
		($in, $out, $inseconds, $outseconds) = $fuse->getCutmarks($vid, $starttime);
	} else {
		$uncutpath = $fuse->getMountPath($vid) . '/uncut.ts';
		$outseconds = CRS::Media::getDuration($uncutpath, 0);
	}

	# check language(s)
	my $languages = '';
	if (!defined($props->{'Record.Language'}) or $props->{'Record.Language'} eq '') {
		$failreason = 'NO LANGUAGE SET!';
		$fail = 1;
	} else {
		$languages = $props->{'Record.Language'};
		# filter undefined tracks for new property Encoding.Language
		$languages =~ s/und//g;
		$languages =~ s/--+/-/g;
		$languages =~ s/^-//;
		$languages =~ s/-$//;
	}

	my %newprops = ( );

	if ($cutmarksvalid > 0) {
		# Until here, the time based cutmarks are strings. Now we need to
		# - calculate with them
		# - use a canonical form (e.g. no trailing zeroes).
		# This is done by using bignum, forcing numerical treatment (adding zero)
		# and later forcing string conversion when assigning property values.

		$inseconds = 0 + $inseconds;
		$outseconds = 0 + $outseconds;
		my $diffseconds = 0;
		$diffseconds = 0 + $outseconds - $inseconds if (defined($outseconds) && defined($inseconds));
		$newprops{'Record.Cutin'} = "" . $in;
		$newprops{'Record.Cutinseconds'} = "" . $inseconds;
		$newprops{'Record.Cutdiffseconds'} = "" . $diffseconds;
		$newprops{'Record.Cutout'} = $out if (defined($out));
		$newprops{'Record.Cutoutseconds'} = "" . $outseconds if (defined($outseconds));
	}

	$newprops{'Processing.Intro.Duration'} = "" . (0 + $introduration) if (defined($introduration));
	$newprops{'Processing.File.Intro'} = $intropath if (defined($intropath) && $intropath ne $orig_intropath);
	$newprops{'Processing.File.Outro'} = $outropath if (defined($outropath) && $outropath ne $orig_outropath);
	$newprops{'Encoding.Language'} = $languages if (defined($languages));

	if ($fail > 0) {
		print STDERR "failing ticket because: $failreason\n";
		$tracker->setTicketFailed($tid, $failreason);
		die ($failreason);
	}

	$tracker->setTicketProperties($tid, \%newprops);

	$tracker->setTicketDone($tid, 'Cut postprocessor: cut completed, metadata written.');
	# indicate short sleep to wrapper script
	exit(100);
}



