#!/usr/bin/perl -W

require CRS::Auphonic;
require C3TT::Client;
require boolean;
use File::Basename qw(dirname);
use Data::Dumper;

my ($secret, $token) = ($ENV{'CRS_SECRET'}, $ENV{'CRS_TOKEN'});

if (!defined($token)) {
	# print usage
	print STDERR "Too few information given!\n\n";
	print STDERR "set environment variables CRS_SECRET and CRS_TOKEN\n\n";
	exit 1;
}

# fetch ticket ready to state postencoding, thus ready to be transmitted to auphonic
my $tracker = C3TT::Client->new();
my $ticket = $tracker->assignNextUnassignedForState('encoding','postencoding');

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for postencoding\n";
} else {
	my $tid = $ticket->{id};
	my $props = $tracker->getTicketProperties($tid);
	my $vid = $props->{'Fahrplan.ID'};
	print "got ticket # $tid for event $vid\n";

	my $auphonicflag = 'no';
	$auphonicflag = $props->{'Processing.UseAuphonic'} if defined ($props->{'Processing.UseAuphonic'});

	if ($auphonicflag ne 'yes') {
		my $jobfile = $tracker->getJobFile($tid);
		utf8::encode($jobfile);
		my $jobfilePath = $props->{'Processing.Path.Tmp'}.'/job-'.$tid.'-foo.xml';

		# download jobfile into a physical file
		open(my $file, ">", $jobfilePath) or die $!;
		print $file "$jobfile";
		close $file;

		# locate exmljob-filtered.pl by tracker property
		my $perlPath = $props->{'Processing.Path.Exmljob'};
		if (!defined($perlPath) || $perlPath eq '') {
			print STDERR "Processing.Path.Exmljob is missing!";
			sleep 5;
			die;
		}

		# execute exmljob-filtered.pl with the downloaded jobfile
		my $perlDir = dirname($perlPath);
		chdir $perlDir;
		$output = qx ( perl "$perlPath" -t postencoding "$jobfilePath" );
		if ($?) {
			$tracker->setTicketFailed($tid, "postencoding failed! Status: $? Output: '$output'");
			die;
		}
		$tracker->setTicketDone($tid, 'postencoding executed successfully');
		exit 0;
	}

	# auphonic authentication via token - the token is stored as a project property in the tracker
	my $auphonicToken = $props->{'Processing.Auphonic.Token'};

	# the chosen auphonic preset configures all filters
	my $auphonicPreset = $props->{'Processing.Auphonic.Preset'};

	# construct input file path
	my $file1 = $props->{'Processing.Path.Tmp'}.'/'.$vid.'-'.$props->{'EncodingProfile.Slug'}.'.'.$props->{'EncodingProfile.Extension'};
	my $auphonic = CRS::Auphonic->new($auphonicToken);

	if (defined($props->{'Processing.Auphonic.SpeedLimit'})) {
		$auphonic->setSpeedLimit($props->{'Processing.Auphonic.SpeedLimit'});
	}

	# upload audio-file to auphonic and start the production
	print "Starting production for $vid\n";
	my $auphonic_1 = $auphonic->startProduction($auphonicPreset, $file1, $props->{'Project.Slug'}.'-'.$vid) or die $!;

	if (!defined($auphonic_1)) {
		print STDERR "Starting production for $vid failed!\n";
		$tracker->setTicketFailed($tid, "Starting production failed!");
		die;
	}

	# fetch the auphonic production uuid and store it into a tracker property
	my $uuid1 = $auphonic_1->getUUID();
	print "Started production for $vid as '$uuid1'\n";
	my %props_new = (
		'Processing.Auphonic.ProductionID1' => $uuid1,
	);

	# upload changed properties to tracker
	$tracker->setTicketProperties($tid, \%props_new);
	# $tracker->setTicketDone($tid, 'Auphonic production started'); # TODO optional machen fuer anderes pipeline layout?
}

# query tickets that are in postencoding state and assigned to this worker
print "querying for assigned ticket in state postencoding ...\n";
my $tickets = $tracker->getAssignedForState('encoding', 'postencoding');

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

	# auphonic login token and uuids of the auphonic productions
	my $auphonicToken = $props->{'Processing.Auphonic.Token'};
	my $uuid1 = $props->{'Processing.Auphonic.ProductionID1'};

	# poll production states
	my $a1 = CRS::Auphonic->new($auphonicToken, $uuid1);
	if (!$a1->isFinished()) {
		print "production $uuid1 not done yet.. skipping\n";
		next;
	}

	# download files
	my $dest1 = $props->{'Processing.Path.Output'}.'/'.$vid.'-'.$props->{'EncodingProfile.Slug'}.'.'.$props->{'EncodingProfile.Extension'};

	print "downloading file from Auphonic... to $dest1\n";
	if (!$a1->downloadResult($dest1)) {
		$tracker->setTicketFailed($tid, 'download of $vid from auphonic failed!');
	} else {
		# done
		$tracker->setTicketDone($tid);
	}
	print "sleeping a while...\n";
	sleep 5;
}

