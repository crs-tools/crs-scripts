#!/usr/bin/perl -W

use strict;
require C3TT::Client;
require boolean;

# Call this script with secret and token as env variable!

my ($secret, $token) = ($ENV{'CRS_SECRET'}, $ENV{'CRS_TOKEN'});

if (!defined($token)) {
	# print usage
	print STDERR "No tracker credentials in environment!\n\n";
	exit 1;
}

my $tracker = C3TT::Client->new();
my $tickets = $tracker->GetTicketsForState('recording', 'finalized');
my $projectfilter = $ARGV[0];

if (!($tickets) || 0 == scalar(@$tickets)) {
	print "no tickets available.\n";
	exit 0;
}

print "found " . scalar(@$tickets) ." tickets\n";

foreach (@$tickets) {
	my $ticket = $_;
	my $tid = $ticket->{id};
	my $vid = $ticket->{fahrplan_id};
	my $props = $tracker->getTicketProperties($tid);
	$vid = $props->{'Fahrplan.ID'} if ($vid < 1);
	my $project = $props->{'Project.Slug'};
	$project = 'undefined' unless defined ($project);
	print "got ticket # $tid for event $vid in project $project\n";

	if (defined($projectfilter) && $projectfilter ne '') {
		# there is a project slug on the cmdline, use it to filter tickets
		if ($project ne $projectfilter) {
			print "  ticket $tid does not belong to project $projectfilter, ignoring\n";
			next;
		}
	}

	if ($ticket->{failed}) {
		print "  ticket is failed, ignoring\n";
		next;
	}
	if ($ticket->{handle_id} ne '') {
		print "  WARNING: ticket $tid is assigned\n";
	}
	if (!defined($props->{'Record.MountCmd'}) || $props->{'Record.MountCmd'} eq '') {
		print "  ticket $tid has no mount command in the properties\n";
		next;
	}

	my $cmd = $props->{'Record.MountCmd'};

	# TODO create mount directory, for now assume it is the same machine and directories exist 
	# from previous activity

	print "  executing '$cmd'\n";
	qx / $cmd /;

}

