package CRS::Media;

use strict;

sub getDuration {
	my ($fullpath, $default, undef) = @_;

	if (!defined($fullpath)) {
		print STDERR "no path given!\n";
	       	return $default;
       	}
	if (! -f $fullpath) {
		print STDERR "path '$fullpath' is no file!\n";
	       	return $default;
       	}
	if (! -r $fullpath) {
		print STDERR "path '$fullpath' is not readable (permission problem?)\n";
	       	return $default;
       	}
	
	my $duration = $default;

	my @ffprobe = qx ( ffprobe -i "$fullpath" -hide_banner -print_format flat -show_entries stream=duration -of default=noprint_wrappers=1:nokey=0 2>/dev/null );
	foreach (@ffprobe) {
		if ( $_ =~ /^duration=([0-9\.]+)/ ) {
			# get the shortest stream duration
			$duration = $1 unless ($duration < $1 and $duration > 0);
		}
	}

	return $duration;
}

1;
