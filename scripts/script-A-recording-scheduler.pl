#!/usr/bin/perl -W

require POSIX;
require CRS::Fuse::VDV;
require C3TT::Client;

use POSIX qw(strftime);
use boolean;
use Time::Piece;

# Call this script with secret and project slug as parameter!

my ($secret, $token) = ($ENV{'CRS_SECRET'}, $ENV{'CRS_TOKEN'});
my $url = "http://tracker.fem-net.de/rpc";

if (!defined($token)) {
	# print usage
	print STDERR "Too few parameters given!\nUsage:\n\n";
	print STDERR "./script-.... <secret> <token>\n\n";
	exit 1;
}

my $target_type = 'recording';
my $target_state = 'recording';

# default padding of record start and stop:
my $startpadding = 300;
my $endpadding = 900;

my $filter = {};
# filter recording events
$filter->{'Record.StartedBefore'} = strftime('%F %T',localtime(time + $startpadding));
#$filter->{'Record.EndedBefore'} = localtime(time+$endpadding)->strftime('%F %T');

#######################################

$|=1;

my $tracker = C3TT::Client->new($url, $token, $secret, 'record');

my $tickets_left = 1;

while($tickets_left) {
    print "querying for ticket in state $target_state ...";
    my $ticket = $tracker->assignNextUnassignedForState($target_type, $target_state, $filter);
	print "\n";
	if(!$ticket) {
	    $tickets_left = 0;
		print "no tickets currently $target_state. exiting...\n";
		last;
	}

	print "found ticket #" . $ticket->{id} . ". ";

    if((Time::Piece->strptime($ticket->{time_end},'%Y-%m-%d %T')->epoch - localtime()->tzoffset - time) + $endpadding < 0) {
        print "event has already ended some time ago. set to recorded...\n";
        $tracker->setTicketDone($ticket->{id});
    } else {
        print "set to $target_state. sleeping a second...\n";
    }
	sleep 1;
}