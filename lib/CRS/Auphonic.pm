package CRS::Auphonic;

use WWW::Curl::Easy;
use WWW::Curl::Form;
use JSON qw( decode_json );
use File::Fetch;
use Data::Dumper;

sub getProductionInfoFromFile {
	my $jsonfile = shift;
	open INPUT, '<'.$jsonfile or die $!;
	undef $/;
	my $content = <INPUT>;
	close INPUT;
	$/ = "\n";

	return getProductionInfo($content);
}

sub getProductionInfo {
	my $content = shift;
#print "\n----\n".$content."\n-----\n";
	my $decoded = decode_json($content);
	my %ret;
	$ret{'uuid'} =  $decoded->{'data'}{'uuid'};
	$ret{'status'} =  $decoded->{'data'}{'status'};
	my $files = $decoded->{'data'}{'output_files'};
	$tmp = pop(@$files);
	if (defined($tmp)) {
		$ret{'url'} =  $tmp->{'download_url'};
		$ret{'filename'} =  $tmp->{'filename'};
	}
#print $ret{'uuid'} . "   " . $ret{'status'} . "  " . $ret{'url'} . "  " . $ret{'filename'} . "\n\n";
#print Dumper($tmp); 
	return %ret;
}

sub getProductionJSON {
	my $uuid = shift;
	my $authtoken = shift;
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
	my $authtoken = shift;
	my $preset = shift;
	my $file = shift;
	my $title = shift;
	my $url = 'https://auphonic.com/api/simple/productions.json';
        my $curl = WWW::Curl::Easy->new;

        $curl->setopt(WWW::Curl::Easy::CURLOPT_HEADER,1);
	$curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPHEADER(), ['Authentication: Bearer ' . $authtoken]);
	$curl->setopt(WWW::Curl::Easy::CURLOPT_POST(), 1);
        $curl->setopt(WWW::Curl::Easy::CURLOPT_URL, $url);

	my $request = "preset=$preset&action=start&input_file=\@$file&title=$title";
	$curl->setopt(WWW::Curl::Easy::CURLOPT_POSTFIELDS(), $request);

        my $body;
	$curl->setopt(WWW::Curl::Easy::CURLOPT_WRITEDATA,\$body);
	my $retcode = $curl->perform;
	if ($retcode == 0) {
		my $info = getProductionInfo($body);
		return $info{'uuid'};
	}
	my $response_code = $curl->getinfo(WWW::Curl::Easy::CURLINFO_HTTP_CODE);
	print STDERR "Start production returns $response_code\n";
}


sub downloadResult {
	my $uuid = shift;
	my $authtoken = shift;
	my $path = shift;

	my %info = CRS::Auphonic::getProductionInfo(CRS::Auphonic::getProductionJSON($uuid, $authtoken));
	my $dest = $path . '/' . $info{'filename'};
	my $url = $info{'url'} . "?bearer_token=" . $authtoken;

print "downloading $url to $path \n";
	my $ff = File::Fetch->new('uri' => $url);
	my $where = $ff->fetch('to' => $path);
	print $ff->error() . "\n";
	print STDERR "download: " . $where ."\n";

}

1;
