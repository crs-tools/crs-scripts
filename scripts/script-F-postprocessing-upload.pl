#!/usr/bin/perl -W

use CRS::Tracker::Client;
use CRS::Paths;
use boolean;
use Sys::Hostname;

my $tracker = CRS::Tracker::Client->new();
my $ticket;
if (defined($ENV{'CRS_ROOM'}) && $ENV{'CRS_ROOM'} ne '') {
        my $filter = {};
        $filter->{'Fahrplan.Room'} = $ENV{'CRS_ROOM'};
        $ticket = $tracker->assignNextUnassignedForState('encoding', 'postprocessing', $filter);
} else {
        $ticket = $tracker->assignNextUnassignedForState('encoding', 'postprocessing');
}

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for postprocessing\n";
} else {
	my $tid = $ticket->{id};
	print "postprocessing ticket # $tid\n";

	my $props = $tracker->getTicketProperties($tid);
	if (defined($props->{'Fahrplan.Recording.Optout'}) && $props->{'Fahrplan.Recording.Optout'} eq '1') {
		print "Ticket is opt-out!!\n\n";
		$tracker->setTicketFailed($tid, 'Recording has optout-flag!');
		exit(100);
	}

	if (defined($props->{'Fahrplan.GUID'}) && $props->{'Fahrplan.GUID'} =~ /^FIXME/i) {
		print "Ticket has FIXME GUID!\n\n";
		$tracker->setTicketFailed($tid, 'Recording has invalid Fahrplan.GUID!');
		exit(100);
	}

	if (defined($props->{'Publishing.Upload.SkipSlaves'}) && $props->{'EncodingProfile.IsMaster'} ne 'yes') {
		my $hostname = hostname;
                if (defined($hostname) && index(',' . $props->{'Publishing.Upload.SkipSlaves'} . ',', ",$hostname,") >= 0) {
			print "\nskipping file upload because it belongs to a slave ticket and this worker is in the skiplist!\n";
			sleep 1;
			$tracker->setTicketDone($tid, 'Encoding postprocessor: upload skipped, slave ticket.');
			exit(100);
		}
	}

	my $paths = CRS::Paths->new($props);
	my $srcfile = $paths->getPath('Output') . "/" . $props->{'Fahrplan.ID'} . 
		"-" . $props->{'EncodingProfile.Slug'} . "." . $props->{'EncodingProfile.Extension'};
	print "checking $srcfile...";
	if (! -e $srcfile) {
		$tracker->setTicketFailed($tid, 'Encoding postprocessor: srcfile '.$srcfile.' not found!');
		die "file $srcfile not found\n";
	}
	print " OK\n";
	my $destfile = $props->{'Publishing.UploadTarget'} . '/' . $props->{'Fahrplan.ID'} . "-" . 
		$props->{'EncodingProfile.Slug'} . '.' . $props->{'EncodingProfile.Extension'};
	print "$srcfile (in) -> $destfile (out) ...";
	# rsync: verbose, '-e ssh', keep partially transferred files, keep mtimes
	my $cmd = "rsync --verbose --rsh=ssh --partial --times '$srcfile' '$destfile'";
	my $out = qx( $cmd 2>&1 );
	my $return = $?;
	print " exit=$return\n";
	$tracker->addLog($tid, $out)
	
	if ($return eq '0') {
		$tracker->setTicketDone($tid, "Encoding postprocessor: rsync completed.");
		# indicate short sleep to wrapper script
		exit(100);
	} else {
		my $error = $out;
		$error =~ s/.*(.{1,80})$/$1/m;
		$error =~ s/[\r\n]//mg;
		$tracker->setTicketFailed($tid, "Encoding postprocessor: command '$cmd' failed! Output ends with: '$error'");
	}
}
