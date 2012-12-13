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

	# fetch metadata

	my $props = $tracker->getTicketProperties($tid);

	# preparation of new metadata
	
	my $path = '/mnt/fem-storage/home/atze/IWUT11/';
	my $srcfile = $props->{'EncodingProfile.Basename'} . "." . $props->{'EncodingProfile.Extension'};
	my $testfile = "/c3mnt/encoded/". $srcfile;

	if (! -f $testfile) {
		$srcfile = $props->{'Encoding.Basename'} . "." . $props->{'EncodingProfile.Extension'};
		my $testfile = "/c3mnt/encoded/". $srcfile;

		if (! -f $testfile) {
			$tracker->setTicketFailed($tid, 'Encoding postprocessor: srcfile '.$srcfile.' not found!');
			print $srcfile ."  ". $path;
			exit 1;
		}
	}

	my $now = POSIX::strftime('%Y.%m.%d_%H:%M:%S', localtime());
	$count = 0 unless defined($count) and $count =~ /^\d+$/;
	$count++;

	# releasing file

		# TODO upload essence file
		#print '/bin/bash /home/ecki/tracker/release2.sh ' . $srcfile . ' ' . $path;
		$rc=system('cp ' . $testfile . ' ' . $path);

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

