#!/usr/bin/perl

use strict;
use warnings;

use constant DEBUG => 1;

require Data::Dumper;
import  Data::Dumper qw(Dumper);
require RPC::XML;
require RPC::XML::Client;

my $trackerurl = 'http://tracker.fem.tu-ilmenau.de/rpc';

# Parameters: project and then login, password or hostname, secret
sub initTracker {
	my %opt = @_;

	my $cli = RPC::XML::Client->new($trackerurl);
	my $resp;
	my $token;
	if ($opt{login} and $opt{password}) {
		$resp = $cli->send_request(
			'C3TT.login', #TODO gibts die noch?
			RPC::XML::string->new($opt{login}),
			RPC::XML::string->new($opt{password})
		);
	} elsif ($opt{hostname} and $opt{secret}) {
		require Digest::MD5;
		$token = Digest::MD5::md5_hex($opt{hostname}.$opt{secret});
		$resp = $cli->send_request(
			'C3TT.register',
			RPC::XML::string->new($opt{hostname}),
			RPC::XML::string->new($token)
		);
	} else {
		warn 'Need login&password or hostname&secret';
		return undef;
	}
	if (ref($resp)) {
		if ($resp->is_fault) {
			print "Fehler bei Login RPC-Methode\n" if DEBUG;
			print Dumper($resp) if DEBUG;
		} else {
			my $ret = $resp->value();
			return undef if ($ret eq 'BAD_LOGIN');
			if ($token) {
				$trackerurl .= '/uid/'.$token;
			} else {
				$trackerurl .= '/uid/'.$ret;
			}
			setCurrentProject($opt{project});
			return $ret;
		}
	} else {
		print "RPC-Fehler: $resp\n";
	}
	return undef;
}

sub setCurrentProject {
	my ($project) = @_;
	my $ret = common_getSingleInt(
		'C3TT.setCurrentProject',
		RPC::XML::string->new($project)
	);
	if ($ret eq '1') {
		#TODO rueckgabe is fantasie, muss noch angepasst werden
		return 1;
	}
	print "Unbekanntes Projekt: $project\n";
	my @ret2 = getProjects();
	print " Projekte auf Tracker:\n";
	foreach (@ret2) {
		print "  $_\n";
	}
}

sub getProjects {
	return common_getRpcArray(
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

	my $cli = RPC::XML::Client->new($trackerurl);
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

	print "Suche Ticket mit ID $tid \n" if DEBUG;
	my %r = getTicketProperties($tid);
	return $r{$propname};
}

sub getTicketProperties {
	my ($tid, $pattern) = @_; #TODO parameter pattern des RPC calls evtl. nutzen

	print "Suche Ticket Properties fuer ID $tid \n" if DEBUG;
	my %ret = common_getRpcHash(
		'C3TT.getTicketProperties', 
		RPC::XML::int->new($tid),
		RPC::XML::string->new($pattern)
	);
	print "Properties gefunden: " . Dumper (\%ret) . "\n" if DEBUG;
	return %ret;
}

sub ping() {
	my ($ticket_id, $status, $logdelta) = @_;

#        my $workaround = $trackerurl;
#        $workaround =~ s{/uid/}{/eid/}smo; #TODO ??? WTF
	my $cli = RPC::XML::Client->new($trackerurl);
	print "Ping\n" if DEBUG;
	my $resp = common_getSingleHash(
		'C3TT.ping', 
		RPC::XML::int->new($ticket_id), 
		RPC::XML::int->new($status),
		RPC::XML::string->new($logdelta));
	if (ref($resp)) {
		if ($resp->is_fault) {
			print "FEHLER: " . Dumper($resp->value);
		}
		return $resp;
	} else {
		print "RPC-Fehler: $resp\n";
	}
}

sub getParentTicketProperties {
	my ($tid) = @_;
	my %tmp = common_getRpcHash('C3TT.getParentTicketById', RPC::XML::int->new($tid));
	print "Parent properties: " . Dumper(%tmp) . "\n" if DEBUG;
	return %tmp;
}

sub getVIDfromTicketID {
	my ($tid) = @_;
	my $ret = getTicketProperty($tid, 'Fahrplan.ID');
	return $ret if (defined($ret));
	return getTicketProperty($tid, 'Event.ID');
}

sub setTicketProperties {
	my ($tid, $hashref) = @_;

	return unless defined $hashref;
	my %props = %$hashref;
	print "Setze properties von Ticket $tid \n" if DEBUG;
	foreach (keys(%props)) {
		my $k = $_;
		my $v = $props{$k};
		print "Setze property $k auf '$v' \n" if DEBUG;
		common_executeVoid(
			'C3TT.setTicketProperty',
			RPC::XML::int->new($tid),
			RPC::XML::string->new($k),
			RPC::XML::string->new($v)
		);
	}
}

sub grabNextTicketInState {
	my ($state) = @_;

	print "Hole freies Ticket mit Status '$state'\n" if DEBUG;
	return common_getSingleInt(
		'C3TT.assignNextUnassignedForState',
		RPC::XML::string->new($state)
	);
}

sub releaseTicketToNextState {
	my ($tid, $log) = @_;

	return undef unless ($tid =~ /^\d+$/);
	print "Entlasse Ticket $tid in naechsten Status\n" if DEBUG;
	return common_executeVoid(
		'C3TT.setTicketDone', 
		RPC::XML::int->new($tid),
		RPC::XML::string->new($log)
	);
}

sub releaseTicketAsBroken {
	my ($tid, $log) = @_;

	return undef unless ($tid =~ /^\d+$/);
	print "Markiere Ticket $tid als failed \n" if DEBUG;
	return common_executeVoid(
		'C3TT.setTicketFailed', 
		RPC::XML::int->new($tid),
		RPC::XML::string->new($log)
	);
}

sub addComment {
	my ($tid, $comment) = @_;

	return unless defined $comment;
	print "Kommentiere Ticket $tid\n" if DEBUG;
	common_executeVoid(
		'C3TT.addLog',
		RPC::XML::int->new($tid),
		RPC::XML::string->new($comment)
	);
}

1;

