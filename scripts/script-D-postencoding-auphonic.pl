#!/usr/bin/perl -W

require CRS::Auphonic;
require C3TT::Client;
require boolean;
use Data::Dumper;

my ($secret, $token) = ($ENV{'CRS_SECRET'}, $ENV{'CRS_TOKEN'});

if (!defined($token)) {
	# print usage
	print STDERR "Too few information given!\n\n";
	print STDERR "set environment variables CRS_SECRET and CRS_TOKEN\n\n";
	exit 1;
}

my $filter = {};
if (defined($ENV{'CRS_PROFILE'})) {
	$filter->{'EncodingProfile.Slug'} = $ENV{'CRS_PROFILE'};
}

my $tracker = C3TT::Client->new();
my $ticket = $tracker->assignNextUnassignedForState('encoding','postencoding', $filter);

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for postencoding\n";
} else {
	my $tid = $ticket->{id};
	my $props = $tracker->getTicketProperties($tid);
	my $vid = $props->{'Fahrplan.ID'};
	print "got ticket # $tid for event $vid\n";

	my $auphonicToken = $props->{'Processing.Auphonic.Token'};
	my $auphonicPreset = $props->{'Processing.Auphonic.Preset'};
	my $audio1 = $props->{'Processing.Path.Tmp'}.'/'.$vid.'-'.$props->{'EncodingProfile.Slug'}.'-audio1.ts';
	my $uuid1 = CRS::Auphonic::startProduction($auphonicToken, $auphonicPreset, $audio1, $props->{'Project.Slug'}.'-'.$vid.'-audio1') or die $!;

	if (!defined($uuid1)) {
		print STDERR "Starting production for audio track1 failed!\n";
		$tracker->setTicketFailed($tid, "Starting production for audio track1 failed!");
		die;
	}

	print "Started production for audio track1 as '$uuid1'\n";
	my %props_new = (
		'Processing.Auphonic.ProductionID1' => $uuid1,
	);

	# check second audio track
	my $lang = $props->{'Record.Language'};
	if ($lang =~ /^..-../) {
		$audio2 = $props->{'Processing.Path.Tmp'}.'/'.$vid.'-'.$props->{'EncodingProfile.Slug'}.'-audio2.ts';
		my $uuid2 = CRS::Auphonic::startProduction($auphonicToken, $auphonicPreset, $audio2, $props->{'Project.Slug'}.'-'.$vid.'-audio2') or die $!;
		print "Started production for audio track2 as '$uuid2'\n";
		if(!defined($uuid2)) {
			$tracker->setTicketFailed($tid, "Starting production for audio track1 failed!");
			die;
		}
		$props_new{'Processing.Auphonic.ProductionID2'} = $uuid2 if(defined($uuid2));
	}
	$tracker->setTicketProperties($tid, \%props_new);
	# $tracker->setTicketDone($tid, 'Auphonic production started'); # TODO optional machen fuer anderes pipeline layout?
}

print "querying for assigned ticket in state postencoding ...\n";
my $tickets = $tracker->getAssignedForState('encoding', 'postencoding', $filter);

if (!($tickets) || 0 == scalar(@$tickets)) {
	print "no assigned tickets currently postencoding. exiting...\n";
	exit 0;
}

print "found " . scalar(@$tickets) ." tickets\n";
foreach (@$tickets) {
	my $ticket = $_;
	my $tid = $ticket->{id};
	my $props = $tracker->getTicketProperties($tid);
	my $vid = $props->{'Fahrplan.ID'};
	print "got ticket # $tid for event $vid\n";

	my $auphonicToken = $props->{'Processing.Auphonic.Token'};
	my $uuid1 = $props->{'Processing.Auphonic.ProductionID1'};
	my $uuid2 = $props->{'Processing.Auphonic.ProductionID2'};

	my $info2;
	my %info1 = CRS::Auphonic::getProductionInfo(CRS::Auphonic::getProductionJSON($uuid1, $auphonicToken));
	if ($info1{'status'} ne '3') {
		print "production $uuid1 not done yet.. skipping\n";
		next;
	}
	if (defined($uuid2)) {
		%info2 = CRS::Auphonic::getProductionInfo(CRS::Auphonic::getProductionJSON($uuid1, $auphonicToken));
		if ($info2{'status'} ne '3') {
			print "production $uuid2 not done yet.. skipping\n";
			next;
		}
	}

#	CRS::Auphonic::downloadResult(%info1, $props->{'Processing.Path.Tmp'});
	CRS::Auphonic::downloadResult($uuid1, $auphonicToken, $props->{'Processing.Path.Tmp'});
	if (defined($uuid2)) {
#		CRS::Auphonic::downloadResult(%info2, $props->{'Processing.Path.Tmp'});
		CRS::Auphonic::downloadResult($uuid2, $auphonicToken, $props->{'Processing.Path.Tmp'});
	}

	my $jobfile = $tracker->getJobFile($tid);
	my $jobfilePath = $props->{'Processing.Path.Tmp'}.'/job-'.$tid.'.xml';
	open(my $file, ">", $jobfilePath) or die $!;
	print $file "$jobfile";
	close $file;

	my $perlPath = $props->{'Processing.Path.Exmljob'};
	if (!defined($perlPath) || $perlPath eq '') {
		print STDERR "Processing.Path.Exmljob is missing!";
		sleep 5;
		die;
	}

	$output = qx ( perl "$perlPath" -t remux "$jobfilePath" );
	if ($?) {
		$tracker->setTicketFailed($tid, "remuxing failed! Status: $? Output: '$output'");
		die;
	}

	$tracker->setTicketDone($tid);
	print "sleeping a while...\n";
	sleep 5;
}

