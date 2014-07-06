#!/usr/bin/perl -W

#require fusevdv;
require C3TT::Client;
require boolean;
use Data::Dumper;

# Call this script with secret and project slug as parameter!

my ($secret, $token) = ($ENV{'CRS_SECRET'}, $ENV{'CRS_TOKEN'});

if (!defined($token)) {
	# print usage
	print STDERR "Too few parameters given!\nUsage:\n\n";
	print STDERR "./script-.... <secret> <token>\n\n";
	exit 1;
}
# TODO URL from env
my $tracker = C3TT::Client->new('http://tracker.fem-net.de/rpc', $token, $secret);
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

	my $base = $props->{'Encoding.Basename'};
	
	my $path = '/opt/crs/encoded/ifc2014/';
	if ($props->{'EncodingProfile.Slug'} eq 'h264-split') {
		my $dest = $base;
		$dest =~ s/de-clean/commented/;
		#print 'cp "' . $path . $vid . '-h264-hq-audio1.mp4" "' . $path . 'finished/audio1/' . $props->{'Encoding.Basename'}.'.mp4';
		my $rc=system('cp "' . $path . $vid . '-h264-hq-audio1.mp4" "' . $path . 'finished/audio1/' . $dest .'.mp4"');
		check_rc($rc, $tid);
		$dest = $base;
		$dest =~ s/de-clean-//;
		$rc=system('cp "' . $path . $vid . '-h264-hq-audio2.mp4" "' . $path . 'finished/audio2/' . $dest.'.mp4"');
		check_rc($rc, $tid);
	} else {
		my $dest = $base;
		$dest =~ s/de-clean/multitrack/;
		my $rc=system('cp "' . $path . $vid . '-h264-hq.mp4" "' . $path . 'finished/multi/' . $dest.'.mp4"');
		check_rc($rc, $tid);
	}
	$tracker->setTicketDone($tid, 'Release Script: released successfully.');
	# indicate short sleep to wrapper
	exit(100);
}

sub check_rc {
	my $rc_ = shift;
	my $tid = shift;
#        my %props = (
#		'Release.Count' => $count,
#		'Release.Datetime' => $now);

	if($rc_==0) {
		#$tracker->setTicketProperties($tid, \%props);

	} else {
		$tracker->setTicketFailed($tid, 'Release Script failed: '. $rc_);
		die 'Ticket failed, exiting';
	}
}

