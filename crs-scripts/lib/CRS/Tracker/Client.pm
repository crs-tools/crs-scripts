# CRS::Tracker::Client
#
# Copyright (c) 2017 Peter Große <pegro@fem-net.de>, all rights reserved
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package CRS::Tracker::Client;

=head1 NAME

CRS::Tracker::Client - Client for interacting with the Congress Recording System Tracker via XML-RPC

=head1 VERSION

Version 0.5

=cut

our $VERSION   = '0.5';

=head1 SYNOPSIS

Generic usage

    use CRS::Tracker::Client;

    my $rpc = CRS::Tracker::Client->new( $uri, $worker_group_token, $secret );

Call a remote method

    my $states = $rpc->getVersion();

=head1 DESCRIPTION

CRS::Tracker::Client is a library for interacting with the CRS Tracker via XML-RPC with automatic encoding 
of all arguments

=head1 METHODS

=head2 new ($url, $worker_group_token, $secret)

Create CRS::Tracker::Client object.

=cut

use strict;
use warnings;

use XML::RPC::Fast;
use vars qw($AUTOLOAD);

use Data::Dumper;
use Net::Domain qw(hostname hostfqdn);
use Digest::SHA qw(hmac_sha256_hex);
use URI::Escape qw(uri_escape);
use IO::Socket::SSL;
use URI::Escape;

use constant PREFIX => 'C3TT.';

# Number of repetitions to perform when the communication with the tracker raises an exception
# E.g.: the client will wait 10s after a fail before retrying (10 * 6 = 1 minute)
use constant REMOTE_CALL_TRIES => 180;
use constant REMOTE_CALL_SLEEP => 10;

sub new {
    my $prog = shift;
    my $self;

    $self->{url} = shift;
    $self->{token} = shift;
    $self->{secret} = shift;

    if (!defined($self->{url})) {
        if (!defined($ENV{'CRS_TRACKER'})) {
            die "no credentials given as parameter or via environment!";
	}
        ($self->{secret}, $self->{token}, $self->{url}) = ($ENV{'CRS_SECRET'}, $ENV{'CRS_TOKEN'}, $ENV{'CRS_TRACKER'});
    }

    # create remote handle
    $self->{remote} = XML::RPC::Fast->new($self->{url}.'?group='.$self->{token}.'&hostname='.hostfqdn, ua => 'LWP', timeout => 30);

    bless $self;

    my $version = $self->getVersion();
    die "be future compatible - tracker RPC API version is $version!\nI'd be more happy with '4.0'.\n" unless ($version eq '4.0');

    return $self;
}

sub AUTOLOAD {

    my $name = $AUTOLOAD;
    $name =~ s/.*://;

    if($name eq 'DESTROY') {
      return;
    }

    my $self = shift;

    if(!defined $self->{remote}) {
      print "No RPC available.";
      exit 1;
    }

	my @args = @_;

    #####################
    # generate signature
    #####################
    # assemble static part of signature arguments
    #                     1. URL  2. method name  3. worker group token  4. hostname
    my @signature_args = (uri_escape_utf8($self->{url}), PREFIX.$name, $self->{token}, hostfqdn);

    # include method arguments if any given
    if(defined $args[0]) {
        foreach my $arg (@args) {
            push(@signature_args, (ref($arg) eq 'HASH') ? hash_serialize($arg) : uri_escape_utf8($arg));
        }
    }

    # generate hash over url escaped line containing a concatenation of above signature arguments
    my $signature = hmac_sha256_hex(join('%26',@signature_args), $self->{secret});

    # add signature as additional parameter
	push(@args,$signature);

    ##############
    # remote call
    ##############
    my $nLoop = REMOTE_CALL_TRIES;
    while($nLoop-- > 0) {
        my $r;
        eval {
            $r = $self->{remote}->call(PREFIX.$name, @args);
        };

        if($@) {
            print "\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
            print "$@";
            print "!!!!!!!!!!!!!! sleeping ".REMOTE_CALL_SLEEP." s !!!!!!!!!!!!!!\n";
            sleep(REMOTE_CALL_SLEEP);
            print "\nretrying $nLoop more times, enabling SSL debugging";
            $Net::SSLeay::trace = 2;
        }
        else {
            $Net::SSLeay::trace = 0;
            return $r;
        }
    }

    print "\ngiving up with\n";
    die $@
}

sub hash_serialize {
    my($data) = @_;

    my $result = "";
    for my $key (keys %$data) {
        $result .= '&' if length $result;
        $result .= '%5B' . uri_escape_utf8($key) . '%5D=' . uri_escape_utf8($data->{$key});
    }
    return $result;
}

1;
