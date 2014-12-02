package CRS::Auphonic;

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
	bless $self;
	return $self;
}

# static method
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

sub getUUID {
	my $self = shift;
	return $self->{uuid};
}

sub isFinished {
	my $self = shift;
	my %info = $self->getProductionInfo();
	if ($info{'status'} eq '3') {
		return 1;
	}
	return 0;
}

sub getProductionInfo {
	my $self = shift;
	my $json = undef;
	if (defined($self->{jsontime}) and $self->{jsontime} > (time() - 60)) {
		$json = $self->{json};
	} else {
		$self->{json} = undef;
		$self->{jsontime} = undef;
		$json = $self->getProductionJSON();
		if (defined($json) and defined($self->{uuid})) {
			$self->{json} = $json;
			$self->{jsontime} = time;
		}
	}
	return getProductionInfoFromJSON($json);
}

sub getProductionJSON {
	my $self = shift;
	my $uuid = $self->{uuid};
	my $authtoken = $self->{authtoken};
	return undef unless defined($uuid) and defined($authtoken);
	my $url = 'https://auphonic.com/api/production/'.$uuid.'.json?bearer_token=' . $authtoken;
        my $curl = WWW::Curl::Easy->new;

        $curl->setopt(WWW::Curl::Easy::CURLOPT_HEADER,0);
	$curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPHEADER(), ['Authentication','Bearer ' . $authtoken]);
        $curl->setopt(WWW::Curl::Easy::CURLOPT_URL, $url);

        my $body;
	$curl->setopt(WWW::Curl::Easy::CURLOPT_WRITEDATA,\$body);
	my $retcode = $curl->perform;
	if ($retcode == 0) {
		return $body;
	}

	my $response_code = $curl->getinfo(WWW::Curl::Easy::CURLINFO_HTTP_CODE);
	print STDERR "Get production JSON for Auphonic production $uuid returns $response_code\n";
}

sub startProduction {
	my $self = shift;
	my $preset = shift;
	my $file = shift;
	my $title = shift;
	my $url = 'https://auphonic.com/api/simple/productions.json';

	my $curl = WWW::Curl::Easy->new;
        $curl->setopt(WWW::Curl::Easy::CURLOPT_HEADER, 0);
	$curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPHEADER(), ['Authorization: Bearer ' . $self->{authtoken}]);
        $curl->setopt(WWW::Curl::Easy::CURLOPT_URL, $url);

	my $form = WWW::Curl::Form->new();
	$form->formadd('preset', $preset);
	$form->formadd('action', 'start');
	$form->formadd('title', $title);
	$form->formaddfile($file, 'input_file', 'multipart/form-data');
	$curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPPOST(), $form);

        my $body;
	$curl->setopt(WWW::Curl::Easy::CURLOPT_WRITEDATA,\$body);
	my $retcode = $curl->perform;
	my $httpcode = $curl->getinfo(CURLINFO_HTTP_CODE);

	if ($retcode == 0 && $curl->getinfo(CURLINFO_HTTP_CODE) == 200) {
		my %info = getProductionInfoFromJSON($body);
		my $ret = CRS::Auphonic->new($self->{authtoken}, $info{'uuid'});
		return $ret;
	}

	print STDERR "Start production returns $httpcode and error is '" .$curl->errbuf . "'\n";
	return undef;
}


sub downloadResult {
	my $self = shift;
	my $dest = shift;

	if (!$self->isFinished()) {
		print STDERR "production is not finished!\n";
		return 0;
	}
	my %info = $self->getProductionInfo();
	my $url = $info{'url'} . "?bearer_token=" . $self->{authtoken};

        my $curl = WWW::Curl::Easy->new;
        $curl->setopt(WWW::Curl::Easy::CURLOPT_HEADER, 0);
        $curl->setopt(WWW::Curl::Easy::CURLOPT_URL, $url);
	$curl->setopt(CURLOPT_CONNECTTIMEOUT, 5);
	$curl->setopt(CURLOPT_TIMEOUT, 60);

	open OUTPUT, ">$dest" or die "Cannot open '$dest'!\n";
	$curl->setopt(CURLOPT_FILE, \*OUTPUT);
	my $retcode = $curl->perform;
	close OUTPUT;
	my $httpcode = $curl->getinfo(CURLINFO_HTTP_CODE);
	if ($retcode == 0 && $curl->getinfo(CURLINFO_HTTP_CODE) == 200) {
		return 1;
	}
	print STDERR "Download production returns $httpcode and error is '" .$curl->errbuf . "'\n";
	return 0;
}

1;
