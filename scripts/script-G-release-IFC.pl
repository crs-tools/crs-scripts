#!/usr/bin/perl -W

use CRS::Tracker::Client;
use POSIX qw(strftime);
use boolean;
use Data::Dumper;

my $tracker = CRS::Tracker::Client->new();
my $ticket = $tracker->assignNextUnassignedForState('encoding', 'releasing');

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
        print "currently no tickets for releasing\n";
} else {
        my $tid = $ticket->{id};
        my $vid = $ticket->{fahrplan_id};
        print "got ticket # $tid for event $vid\n";
        my $props = $tracker->getTicketProperties($tid);
	#print Dumper($ticket);
	#print Dumper($props);

	my $sourcepath = $props->{'Processing.Path.Output'};
	$sourcepath .= '/' . $vid . '-' . $props->{'EncodingProfile.Slug'} . '.' . $props->{'EncodingProfile.Extension'};
	my $destpath = $props->{'Releasing.Path'};
	$destpath .= '/' . $props->{'EncodingProfile.Basename'} . '.' . $props->{'EncodingProfile.Extension'};

	if ($props->{'EncodingProfile.Slug'} eq 'h264-split') {
		my $base = $props->{'Encoding.Basename'};
		my $dest = $base;
		$dest =~ s/de-clean/commented/;
		#print 'cp "' . $path . $vid . '-h264-hq-audio1.mp4" "' . $path . 'finished/audio1/' . $props->{'Encoding.Basename'}.'.mp4';
		my $rc=system('mv "' . $path . $vid . '-h264-hq-audio1.mp4" "' . $path . 'finished/audio1/' . $dest .'.mp4"');
		check_rc($rc, $tid);
		$dest = $base;
		$dest =~ s/de-clean-//;
		$rc=system('mv "' . $path . $vid . '-h264-hq-audio2.mp4" "' . $path . 'finished/audio2/' . $dest.'.mp4"');
		check_rc($rc, $tid);
	} else {
		my $rc=system('cp "' . $sourcepath . '"  "' . $destpath.'"');
		check_rc($rc, $tid);
	}
	$tracker->setTicketDone($tid, 'Release Script: released successfully.');
	# indicate short sleep to wrapper
	exit(100);
}

sub check_rc {
	my $rc_ = shift;
	my $tid = shift;
        my %props = (
#		'Release.Count' => $count,
		'Release.Datetime' => strftime('%FT%TZ', gmtime(time)));

	if($rc_==0) {
		$tracker->setTicketProperties($tid, \%props);

	} else {
		$tracker->setTicketFailed($tid, 'Release Script failed: '. $rc_);
		die 'Ticket failed, exiting';
	}
}

