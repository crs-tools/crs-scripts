#!/usr/bin/perl -W

#require fusevdv;
require C3TT::Client;
require boolean;
use Data::Dumper;

# Call this script with secret and project slug as parameter!

my ($secret, $project) = (shift, shift);

if (!defined($project)) {
	# print usage
	print STDERR "Too few parameters given!\nUsage:\n\n";
	print STDERR "./script-.... <secret> <project slug>\n\n";
	exit 1;
}

my $tracker = C3TT::Client->new('http://tracker.fem.tu-ilmenau.de/rpc', 'C3TT', $secret);
$tracker->setCurrentProject($project);
my $ticket = $tracker->assignNextUnassignedForState('releasing');

if (!defined($ticket) || ref($ticket) eq 'boolean' || $ticket->{id} <= 0) {
	print "currently no tickets for releasing\n";
} else {
	my $tid = $ticket->{id};
	print "releasing ticket # $tid\n";
	#print Dumper($ticket);

	my $zwspeicher = "/mnt/raid/release"; #tmp zwischenspeicher fuers releasen
	my $mirror = "/mnt/raid/mirror";  #pfad zum endgueltigen ort
	my $xxc3 = "29C3";		  #welcher c3
	my $torrenttime = "1s";		  #verzögerung zwischen torrents und dateien

	# fetch metadata

	my $props = $tracker->getTicketProperties($tid);

	# preparation of new metadata
	
	my $path = $tracker->getEncodingProfiles($ticket->{'encoding_profile_id'})->{'mirror_folder'};
	my $srcfile = $props->{'EncodingProfile.Basename'} . "." . $props->{'EncodingProfile.Extension'};
	my $testfile = $zwspeicher . "/" . $srcfile;
	print $props->{'EncodingProfile.Basename'} . "  " . $props->{'Encoding.Basename'} . "\n";

	my $slug = '';
        if ($props->{'EncodingProfile.Basename'} =~ /_([^_]+$)/) {
                $slug = $1;
        }
	
	my $srcfile2 = $props->{'Fahrplan.ID'} . "-" . $slug . "." . $props->{'EncodingProfile.Extension'};
	my $testfile2 = $zwspeicher . "/" . $srcfile2;
	print $srcfile2 ."  ". $srcfile;

	if (! -f $testfile2) {
		$srcfile2 = $props->{'Fahrplan.ID'} . "-" . $slug . "." . $props->{'EncodingProfile.Extension'};
                my $testfile2 = $zwspeicher . "/" . $srcfile2;

		if (! -f $testfile2) {
                        $tracker->setTicketFailed($tid, 'Encoding postprocessor: srcfile '.$srcfile2.' not found!');
                        print $srcfile2 ."  ". $path ."\n";
                        exit 1;
                }
        }

	$rc2=system('mv ' . $zwspeicher . '/' . $srcfile2 . ' ' . $zwspeicher . '/' . $srcfile);

	if($rc2==0)
	{
	}
        else
        {
		my $now2 = POSIX::strftime('%Y.%m.%d_%H:%M:%S', localtime());
	        $count2 = 0 unless defined($count2) and $count2 =~ /^\d+$/;
	        $count2++;
	        $tracker->setTicketProperty($tid, 'Release.Count', $count2);
                $tracker->setTicketProperty($tid, 'Release.Datetime', $now2);
                $tracker->setTicketFailed($tid, 'Umbenennen nicht ok');
        }

	if (! -f $testfile) {
		$srcfile = $props->{'EncodingProfile.Basename'} . "." . $props->{'EncodingProfile.Extension'};
		my $testfile = $zwspeicher . "/" . $srcfile;

		if (! -f $testfile) {
			$tracker->setTicketFailed($tid, 'Encoding postprocessor: srcfile '.$srcfile.' not found!');
			print $srcfile ."  ". $path ."\n";
			exit 1;
		}
	}

	my $now = POSIX::strftime('%Y.%m.%d_%H:%M:%S', localtime());
	$count = 0 unless defined($count) and $count =~ /^\d+$/;
	$count++;

	# releasing file
	$rc=system('/bin/bash /home/ecki/tracker/release.sh ' . $srcfile . ' ' . $path . ' ' . $xxc3 . ' ' . $zwspeicher . ' ' . $mirror . ' ' . $torrenttime);

	# write back to tracker
	
	if($rc==0)
	{
		$tracker->setTicketProperty($tid, 'Release.Count', $count);
		$tracker->setTicketProperty($tid, 'Release.Datetime', $now);

		$tracker->setTicketDone($tid, 'Release Script: released successfully.');
	}
	else
	{
		$tracker->setTicketProperty($tid, 'Release.Count', $count);
		$tracker->setTicketProperty($tid, 'Release.Datetime', $now);

		$tracker->setTicketFailed($tid, 'Release Script failed');
	}
}

