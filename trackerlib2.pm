#!/usr/bin/perl

# 48: initTracker
# 63: refreshUrl
# 70: setCurrentProject
# 75: getProjects
# 84: common_getRpcHash
# 104: common_getRpcArray
# 124: common_executeVoid
# 140: common_getSingleHash
# 159: common_getSingleInt
# 178: getHashKeyForValue
# 190: getTicketProperty
# 198: getTicketProperties
# 212: ping
# 231: getVIDfromTicketID
# 238: setTicketProperty
# 253: setTicketProperties
# 264: getAllUnassignedTicketsInState
# 275: grabNextTicketForState
# 286: releaseTicketToNextState
# 299: setTicketNextState
# 311: releaseTicketAsBroken
# 324: addComment
# 337: initDummyProperties

use strict;
use warnings;

use constant DEBUG => 1;
use constant SIMULATE => 1;

require Data::Dumper;
import  Data::Dumper qw(Dumper);
require RPC::XML;
require RPC::XML::Client;
require Digest::MD5;

my $trackerbase = 'http://tracker.28c3.fem-net.de/rpc/';
my $trackerurl = undef;
my $token = undef;
my $fqdn = undef;
my $project = undef;
my $cli = undef;
my %dummyProperties = ();

# Parameters: hostname, secret, [project]
sub initTracker {
	my %opt = @_;

	print "init RPC \n" if DEBUG;
	if (!defined($opt{'hostname'}) and !defined($opt{'secret'})) {
		print STDERR "too few arguments for initTracker!\n";
		return undef;
	}
	$fqdn = $opt{'hostname'};
	$token = Digest::MD5::md5_hex($fqdn.$opt{'secret'});
	$project = $opt{'project'};
	initDummyProperties() if SIMULATE;
	refreshUrl();
}

sub refreshUrl {
	$trackerurl = $trackerbase . $token . '/' . $fqdn;
	$trackerurl .= "/$project" if defined($project);
	print "new tracker URL: '$trackerurl'\n" if DEBUG;
	$cli = RPC::XML::Client->new($trackerurl) if !SIMULATE;
}

sub setCurrentProject {
	$project = shift;
	refreshUrl();
}

sub getProjects {
	return ('28c3' => '28. C.C.C.', 'iwut11' => 'Ilmenauer bla bla') if SIMULATE;
	return common_getRpcHash(
		'C3TT.getProjects',
		RPC::XML::boolean->new(0),
		RPC::XML::boolean->new(0)
	);
}

sub common_getRpcHash {
	my $function_name = shift;
	my @params        = @_;

	my $cli = RPC::XML::Client->new($trackerurl);
	print "Executing $function_name \n" if DEBUG;
	my $resp = $cli->send_request($function_name, @params);
	if (ref($resp)) {
		if ($resp->is_fault) {
			print "FEHLER: " . Dumper($resp->value);
		} else {
			my $retref = $resp->value();
			return %$retref;
		}
	} else {
		print "RPC-Fehler: $resp\n";
	}
	return {};
}

sub common_getRpcArray {
	my $function_name = shift;
	my @params        = @_;

	print "Executing $function_name \n" if DEBUG;
	my $resp = $cli->send_request($function_name, @params);
	if (ref($resp)) {
		if ($resp->is_fault) {
			print "FEHLER: " . Dumper($resp->value);
		} else {
			my $retref = $resp->value();
			print "Array returned " . Dumper($retref) . "\n" if DEBUG;
			return @$retref;
		}
	} else {
		print "RPC-Fehler: $resp\n";
	}
	return ();
}

sub common_executeVoid {
	my $function_name = shift;
	my @params        = @_;

	my $cli = RPC::XML::Client->new($trackerurl);
	print "Execute: $function_name\n" if DEBUG;
	my $resp = $cli->send_request($function_name, @params);
	if (ref($resp)) {
		if ($resp->is_fault) {
			print "FEHLER: " . Dumper($resp->value);
		}
	} else {
		print "RPC-Fehler: $resp\n";
	}
}

sub common_getSingleHash {
	my $function_name = shift;
	my @params        = @_;

	my $cli = RPC::XML::Client->new($trackerurl);
	print "Execute: $function_name\n" if DEBUG;
	my $resp = $cli->send_request($function_name, @params);
	if (ref($resp)) {
		if ($resp->is_fault) {
			print "FEHLER: " . Dumper($resp->value);
		} else {
			my $retref = $resp->value();
			return %$retref;
		}
	} else {
		print "RPC-Fehler: $resp\n";
	}
}

sub common_getSingleInt {
	my $function_name = shift;
	my @params        = @_;

	my $cli = RPC::XML::Client->new($trackerurl);
	print "Execute: $function_name\n" if DEBUG;
	my $resp = $cli->send_request($function_name, @params);
	if (ref($resp)) {
		if ($resp->is_fault) {
			print "FEHLER: " . Dumper($resp->value);
		} else {
			return $resp->value();
		}
	} else {
		print "RPC-Fehler: $resp\n";
	}
	return undef;
}

sub getHashKeyForValue {
	my ($needle, $haystack) = @_;

	return undef unless defined $needle;

	foreach (keys %$haystack) {
		if (defined $haystack->{$_} and $haystack->{$_} eq $needle) {
			return $_;
		}
	}
}

sub getTicketProperty {
	my ($tid, $propname) = @_;

	print "querying property '$propname' of ticket # $tid \n" if DEBUG;
	my %r = getTicketProperties($tid);
	return $r{$propname};
}

sub getTicketProperties {
	my ($tid, $pattern) = @_; #TODO parameter pattern des RPC calls evtl. nutzen

	print "querying properties of ticket # $tid \n" if DEBUG;
	return %dummyProperties if SIMULATE;
	my %ret = common_getRpcHash(
		'C3TT.getTicketProperties', 
		RPC::XML::int->new($tid),
#		RPC::XML::string->new($pattern)
	);
	print "got properties from tracker: " . Dumper (\%ret) . "\n" if DEBUG;
	return %ret;
}

sub ping {
	my ($ticket_id, $status, $logdelta) = @_;

	print "ping ($ticket_id, '$status', ...)\n" if DEBUG;
	return if SIMULATE;
	my $resp = common_getSingleHash(
		'C3TT.ping', 
		RPC::XML::int->new($ticket_id), 
		RPC::XML::int->new($status),
		RPC::XML::string->new($logdelta));
	if (ref($resp)) {
		if ($resp->is_fault) {
			print STDERR "ERROR: " . Dumper($resp->value);
		}
	} else {
		print STDERR "RPC ERROR: $resp\n";
	}
}

sub getVIDfromTicketID {
	my ($tid) = @_;
	my $ret = getTicketProperty($tid, 'Fahrplan.ID');
	return $ret if (defined($ret));
	return getTicketProperty($tid, 'Event.ID');
}

sub setTicketProperty {
	my ($tid, $key, $value, undef) = @_;
	print "setting property '$key' of ticket # $tid to value '$value' \n" if DEBUG;
	if (SIMULATE) {
		$dummyProperties{$key} = $value;
	} else {
		common_executeVoid(
			'C3TT.setTicketProperty',
			RPC::XML::int->new($tid),
			RPC::XML::string->new($key),
			RPC::XML::string->new($value)
		);
	}
}

sub setTicketProperties {
	my ($tid, $hashref) = @_;

	return unless defined $hashref;
	my %props = %$hashref;
	print "setting properties of ticket # $tid \n" if DEBUG;
	foreach (keys(%props)) {
		setTicketProperty($tid, $_, $props{$_});
	}
}

sub getAllUnassignedTicketsInState {
	my ($state, undef) = @_;

	print "getting all free tickets for state '$state'\n" if DEBUG;
	return (1,2,3) if SIMULATE;
	return common_getRpcHash(
		'C3TT.getAllUnassignedTicketsInState',
		RPC::XML::string->new($state)
	);
}

sub grabNextTicketForState {
	my ($state, undef) = @_;

	print "getting next free ticket for state '$state'\n" if DEBUG;
	return 1 if SIMULATE;
	return common_getSingleInt(
		'C3TT.assignNextUnassignedForState',
		RPC::XML::string->new($state)
	);
}

sub releaseTicketToNextState {
	my ($tid, $log, undef) = @_;

	return undef unless ($tid =~ /^\d+$/);
	print "releasing ticket # $tid with success\n" if DEBUG;
	return if SIMULATE;
	return common_executeVoid(
		'C3TT.setTicketDone', 
		RPC::XML::int->new($tid),
		RPC::XML::string->new($log)
	);
}

sub setTicketNextState {
	my ($tid, undef) = @_;

	return undef unless ($tid =~ /^\d+$/);
	print "moving ticket # $tid to next state\n" if DEBUG;
	return if SIMULATE;
	return common_executeVoid(
		'C3TT.setTicketNextState', 
		RPC::XML::int->new($tid)
	);
}

sub releaseTicketAsBroken {
	my ($tid, $log, undef) = @_;

	return undef unless ($tid =~ /^\d+$/);
	print "releasing ticket # $tid AS BROKEN\n" if DEBUG;
	return if SIMULATE;
	return common_executeVoid(
		'C3TT.setTicketFailed', 
		RPC::XML::int->new($tid),
		RPC::XML::string->new($log)
	);
}

sub addLog {
	my ($tid, $comment) = @_;

	return unless defined $comment;
	print "commenting ticket # $tid\n" if DEBUG;
	return if SIMULATE;
	common_executeVoid(
		'C3TT.addLog',
		RPC::XML::int->new($tid),
		RPC::XML::string->new($comment)
	);
}

sub initDummyProperties {
	%dummyProperties = (
	'Fahrplan.Date' 	=> '2011-12-28',
	'Fahrplan.Start' 	=> '00:15',
	'Fahrplan.Duration' 	=> '01:00',
	'Fahrplan.Room' 	=> 'Saal 1',
	'Fahrplan.ID' 		=> '4721',
	'Fahrplan.Slug' => 'pentanews_game_show_2k11',
	'Fahrplan.Title' => 'Pentanews Game Show 2k11/3',
	'Fahrplan.Abstract' => 'The Penta News Game Show rehashes a collection of absurd, day-to-day news items of 2011 to entertain the audience, let the Net participate, and make it\'s winners heroes.',
	'Fahrplan.Person_list' => 'Alien8, _john, klobs',
	'Fahrplan.Subtitle' => '42 new questions, new jokers, same concept, more fun than last year!',
	'Fahrplan.Type' => 'contest',
	'Fahrplan.Language' => 'en',
	'Fahrplan.Track' => 'Show');

}

1;

