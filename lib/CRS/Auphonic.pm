package CRS::Auphonic;

=head1 NAME

CRS::Auphonic - Library for interacting with Auphonic.com REST API

=head1 VERSION

Version 0.1

=head1 SYNOPSIS

Generic usage

    use CRS::Auphonic;

    my $auphonic = CRS::Auphonic->new('AbCdEfGhIj1234');

Set speed limit for upload in kBytes/second

    $auphonic->setSpeedLimit(2000);

Start a production (returns new object)

    my $auphonic = $auphonic->startProduction($auphonicPreset, '/tmp/test.ogg', 'my first API production');

Poll status (more often than once per minute is not recommended)

	while(!$auphonic->isFinished()) { 
		print ".";
		sleep 60; 
	}

Download processed audio file

	if (!$auphonic->downloadResult('/tmp/processed.ogg')) {
		print "Error downloading file!";
	}

=head1 DESCRIPTION

CRS::Auphonic is a library for interacting with the 
REST API of Auphonic.com.

=head1 METHODS

=head2 new ($authToken, $uuid)

Create CRS::Auphonic object. 
The authToken is mandatory for using the Auphonic API.
The uuid is optional and should be given if the production already exists.

=head2 setSpeedLimit($limit);

Set a speed limit on the upload process (HTTP POST). The value given is
taken as kilobytes per second.

=head2 startProduction ($preset, $file, $title)

Start an Auphonic production. The preset is a string containing
the GUID of a preset that has to be created on the Auphonic web 
page before. The file is the audio file that will be uploaded
to auphonic. The title is an informational string that will be
a property of the production and displayed in the webinterface.

This method returns a new CRS::Auphonic instance!

=head2 getProductionInfo ()

Get some limited information about the production as a hash.
Currently this contains the keys 'uuid', 'status', 'url' and
'filename'.

=head2 getUUID ()

Return the UUID of the production associated to this instance.
This will be the UUID set on constructing the instance, especially
after calling startProduction().

=head2 isFinished ()

Returns 1 if the status of the production is "completed", 0 otherwise.

=head2 downloadResult($destination)

Download the resulting file from Auphonic to the filename given. The
parameter should be a full path and filename. Please note that this 
function downloads only the first of maybe multiple output files of an
Auphonic production.

=head2 getProductionJSON ()

Get the full production information in JSON format as it is
delivered by Auphonic.

=cut

use strict;
use warnings;

use WWW::Curl::Easy;
use WWW::Curl::Form;
use JSON qw( decode_json );

sub new {
	shift;
	my $self;
	$self->{authtoken} = shift;
	$self->{uuid} = shift;

	# just to be safe:
	$self->{authtoken} =~ s/^\s+|\s+$//g ;
	$self->{uuid} =~ s/^\s+|\s+$//g if defined($self->{uuid});

	bless $self;
	return $self;
}

# static method parsing the production json
sub getProductionInfoFromJSON {
	my $content = shift;
	my $decoded = decode_json($content);
	my %ret;
	$ret{'uuid'} =  $decoded->{'data'}{'uuid'};
	$ret{'status'} =  $decoded->{'data'}{'status'};
	my $files = $decoded->{'data'}{'output_files'};
	my $tmp = pop(@$files);
	if (defined($tmp)) {
		$ret{'url'} =  $tmp->{'download_url'};
		$ret{'filename'} =  $tmp->{'filename'};
	}
	return %ret;
}

sub setSpeedLimit {
	my $self = shift;
	$self->{limit} = shift;
}

sub getUUID {
	my $self = shift;
	return $self->{uuid};
}

sub isFinished {
	my $self = shift;
	my %info = $self->getProductionInfo();
	# status 3 = 'done'
	if ($info{'status'} eq '3') {
		return 1;
	}
	return 0;
}

sub getProductionInfo {
	my $self = shift;
	my $json = undef;

	# is a cached version available and not older than 58s?
	if (defined($self->{jsontime}) and $self->{jsontime} > (time() - 58)) {
		$json = $self->{json};
	} else {
		# clear possible existing cache
		$self->{json} = undef;
		$self->{jsontime} = undef;

		# doenload current production status
		$json = $self->getProductionJSON();
		if (defined($json) and defined($self->{uuid})) {
			# update cache timestamp
			$self->{json} = $json;
			$self->{jsontime} = time;
		}
	}

	# return parsed version
	return getProductionInfoFromJSON($json);
}

sub getProductionJSON {
	my $self = shift;
	my $uuid = $self->{uuid};
	my $authtoken = $self->{authtoken};

	# don't do anything without a production uuid and an auth-token
	return undef unless defined($uuid) and defined($authtoken);

	# construct & setup a curl-instance
	my $url = 'https://auphonic.com/api/production/'.$uuid.'.json?bearer_token=' . $authtoken;
	my $curl = WWW::Curl::Easy->new;
	$curl->setopt(WWW::Curl::Easy::CURLOPT_HEADER,0);
	$curl->setopt(WWW::Curl::Easy::CURLOPT_URL, $url);

	# save json-result
	my $body;
	$curl->setopt(WWW::Curl::Easy::CURLOPT_WRITEDATA,\$body);

	# execute & test for success
	my $retcode = $curl->perform;
	if ($retcode == 0) {
		return $body;
	}

	# show http-error otherwise
	my $response_code = $curl->getinfo(WWW::Curl::Easy::CURLINFO_HTTP_CODE);
	print STDERR "Get production JSON for Auphonic production $uuid returns $response_code\n";
}

sub startProduction {
	my $self = shift;
	my $preset = shift;
	my $file = shift;
	my $title = shift;

	# just to be safe:
	$preset =~ s/^\s+|\s+$//g ;

	# construct & setup a curl-instance
	my $url = 'https://auphonic.com/api/simple/productions.json';
	my $curl = WWW::Curl::Easy->new;
	$curl->setopt(WWW::Curl::Easy::CURLOPT_HEADER, 0);
	$curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPHEADER(), ['Authorization: Bearer ' . $self->{authtoken}]);
	$curl->setopt(WWW::Curl::Easy::CURLOPT_URL, $url);
	if (defined($self->{limit})) {
		$curl->setopt(WWW::Curl::Easy::CURLOPT_MAX_SEND_SPEED_LARGE, (0 + $self->{limit}) * 1024);
	}

	# construct & setup a html-like form set
	my $form = WWW::Curl::Form->new();
	$form->formadd('preset', $preset);
	$form->formadd('action', 'start');
	$form->formadd('title', $title);
	$form->formaddfile($file, 'input_file', 'multipart/form-data');
	$curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPPOST(), $form);

	# save json-result
	my $body;
	$curl->setopt(WWW::Curl::Easy::CURLOPT_WRITEDATA,\$body);

	# execute
	my $retcode = $curl->perform;
	my $httpcode = $curl->getinfo(CURLINFO_HTTP_CODE);

	# test for success
	if ($retcode == 0 && $httpcode == 200) {
		# parse production json
		my %info = getProductionInfoFromJSON($body);

		# return a new CRS::Auphonic instance, this time with a uuid set
		my $ret = CRS::Auphonic->new($self->{authtoken}, $info{'uuid'});
		return $ret;
	}

	# show http-error otherwise
	print STDERR "Start production returns $httpcode and error is '" .$curl->errbuf . "'\n";
	return undef;
}

sub downloadResult {
	my $self = shift;
	my $dest = shift;

	# downloading is not possible unless the production has finished
	if (!$self->isFinished()) {
		print STDERR "production is not finished!\n";
		return 0;
	}

	# fetch production info from auphonic
	my %info = $self->getProductionInfo();
	my $url = $info{'url'} . "?bearer_token=" . $self->{authtoken};

	# construct & setup a curl-instance
	my $curl = WWW::Curl::Easy->new;
	$curl->setopt(WWW::Curl::Easy::CURLOPT_HEADER, 0);
	$curl->setopt(WWW::Curl::Easy::CURLOPT_URL, $url);
	$curl->setopt(CURLOPT_CONNECTTIMEOUT, 5);
	$curl->setopt(CURLOPT_TIMEOUT, 1800);

	# open output file
	open OUTPUT, ">$dest" or die "Cannot open '$dest'!\n";
	$curl->setopt(CURLOPT_FILE, \*OUTPUT);

	# execute curl request & close output file
	my $retcode = $curl->perform;
	close OUTPUT;

	# test for success
	my $httpcode = $curl->getinfo(CURLINFO_HTTP_CODE);
	if ($retcode == 0 && $httpcode == 200) {
		return 1;
	}

	# show http-error otherwise
	print STDERR "Download production returns $httpcode and error is '" .$curl->errbuf . "'\n";
	return 0;
}

1;
