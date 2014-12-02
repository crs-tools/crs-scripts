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
sub getProductionInfoFromFile {
	my $jsonfile = shift;
	open INPUT, '<'.$jsonfile or die $!;
	undef $/;
	my $content = <INPUT>;
	close INPUT;
	$/ = "\n";

	return getProductionInfoFromJSON($content);
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

sub getProductionInfo {
	my $self = shift;
	return getProductionInfoFromJSON($self->getProductionJSON());
}

sub getProductionJSON {
	my $self = shift;
	my $uuid = $self->{uuid};
	my $authtoken = $self->{authtoken};
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
	my $path = shift;

	my %info = $self->getProductionInfo();
	if ($info{'status'} ne '3') {
		print STDERR "production is not finished!\n";
		return;
	}
	my $dest = $path . '/' . $info{'filename'};
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
		return;
	}
	print STDERR "Download production returns $httpcode and error is '" .$curl->errbuf . "'\n";
}

1;
