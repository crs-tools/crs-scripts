
package CRS::Fuse;

our $default = ();
$default->{'binpath'} = '/usr/bin';

$default->{'fps'} = 25;
$default->{'defaultfiles'} = 20;  # Anzahl der Schnipsel, wenn keine Anzahl gegeben wird (Standard bei 6min-Schnipsel == 2h)
$default->{'defaultpieceframes'} = 3*60*$default->{'fps'};  # Laenge eines Schnipsels in Frames (Standard: 3 min.)

$default->{'debug'} = 1;

#my $outrofile = '';

use POSIX;
use DateTime;
use strict;
use CRS::Paths;

sub new {
    my $class = shift;
    my $self = {};
    bless $self;

    my $args = shift;
    my $paths = CRS::Paths->new($args);

    # merge defaults and parameters from constructor
    my %cfg = (%{$default}, %{$args});

    foreach(keys %cfg) {
        print "setting $_='".$cfg{$_}."'\n" if defined($cfg{$_}) and defined($cfg{debug});
        $self->{$_} = $cfg{$_};
    }

    $self->{'paths'} = $paths;
    # check if some defaults are replaced
    $self->{'fps'} = $self->{'Capture.FPS'} if defined $self->{'Capture.FPS'};
    $self->{'cutError'} = '';

    return $self;
}

# start has syntax YYYY-MM-DD-hh:mm
# duration has syntax hh:mm
# paddings are given in seconds
# returns ($paddedstart, $paddedlength)
# with paddedstart in syntax YYYY.MM.DD-HH_MM_SS,
# paddedlength in seconds
sub getPaddedTimes {
	my ($start, $duration, $startpadding, $endpadding, undef) = @_;
	print "getPaddedTimes ($start, $duration, $startpadding, $endpadding)\n" ;

	my $startdatetime = undef;
	if ($start =~ /(\d+)-(\d+)-(\d+)-(\d+)[\:-](\d+)/) {
		$startdatetime = DateTime->new(
			year      => $1,
			month     => $2,
			day       => $3,
			hour      => $4,
			minute    => $5,
			second    => 0,
			time_zone => 'Europe/Berlin',
		);
	} else {
		print STDERR "start parameter has incorrect format!\n";
		return undef;
	}
	$startdatetime->add('seconds' => -$startpadding) if (defined($startpadding) and $startpadding =~ /^-?[0-9]+$/);
	my $paddedstart = $startdatetime->ymd('.') . '-' . $startdatetime->hms('_');

	my $paddedlength = getPaddedDuration($duration, $startpadding, $endpadding);

	return ($paddedstart, $paddedlength);
}

# duration has syntax hh:mm or hh:mm:ss
# paddings are given in seconds
# returns $paddedlength in seconds
sub getPaddedDuration {
	my ($duration, $startpadding, $endpadding, undef) = @_;
	$startpadding = 0 unless defined($startpadding);
	$endpadding = 0 unless defined($endpadding);
	print "getPaddedTimes ($duration, $startpadding, $endpadding)\n" ;

	my $durationseconds = undef;
	if ($duration =~ /^(\d+):(\d+)$/) {
		$durationseconds = (($1 * 60) + $2) * 60;
	} elsif ($duration =~ /^(\d+):(\d+):(\d+)$/) {
		$durationseconds = ((($1 * 60) + $2) * 60) + $3;
	} else {
		print STDERR "duration has wrong format!\n";
		return undef;
	}
	return ($durationseconds + $startpadding + $endpadding);
}

sub getFuseMounts {
	my $self = shift;
	return () unless defined($self->{fuse_binary});

	my @ret = ();
	open(IN, '</proc/mounts') or die "cannot open /proc/mounts:$!\n";
	grep {
		/^fuse-\w+\ \/.+\/(\d+)\s/ and push (@ret, $1);
	} (<IN>);
	close(IN);
	return @ret;
}

sub getMountPath {
	my ($self, $vid) = @_;
	return unless defined($vid);
	my $base = $self->{'paths'}->getPath('Raw');
	die "ERROR: Processing.Path.Raw is not defined!\n" unless defined $base;
	if (defined($self->{'Project.Slug'}) && defined($self->{'Fahrplan.Room'})) {
		return $base . '/' . $self->{'Project.Slug'} . '/' . $self->{'Fahrplan.Room'} . "/$vid";
	}
	return "$base/$vid";
}

sub getCapturePath {
	my ($self, $room) = @_;
	my $base = $self->{'paths'}->getPath('Capture');
	if (! -e $base && ! -d $base) {
		print STDERR "ERROR: Processing.Path.Capture ('$base') seems to be totally wrong!\n";
		return;
	}
	if (-e -d "$base/$room") {
		return "$base/$room";
	}
	return $base;
}

sub isVIDmounted {
	my ($self, $vid) = @_;
	return 0 unless defined($vid);
	my @t = $self->getFuseMounts();
	foreach(@t) {
		if ($_ eq $vid) {
			my $pidfile = $self->getMountPath($vid).'/pid';
			if (-f$pidfile) {
				return 1;
			} else {
				# FUSE seems to be gone
				$self->doFuseUnmount($vid);
			}
		}
	}
	return 0;
}

sub doFuseUnmount {
	my ($self, $vid) = @_;
	return unless defined ($vid);
	my $p = $self->getMountPath($vid);
	qx ( fusermount -u "$p" -z );
}

sub getIntro {
	my ($self, $suffix, $id) = @_;
	my $start = $self->{'paths'}->getPath('Intros');
	return unless defined $start;
	return $self->getCustomFile($start, 'intro', $suffix, $id);
}

sub getOutro {
	my ($self, $suffix, $id) = @_;
	my $start = $self->{'paths'}->getPath('Outro');
	$start = $self->{'paths'}->getPath('Outros') if (!defined($start));
	return unless defined $start;
	return $self->getCustomFile($start, 'outro', $suffix, $id);
}

sub getCustomFile {
	my ($self, $dir, $name, $suffix, $id) = @_;
	$suffix = '' unless defined ($suffix);
	return unless defined $dir;
	
	# Test if the property points to a valid location
	if (-e $dir) {
	# Test if property points to a directory
		if (-d $dir) {
			# Test for file named id.suffix in this dir
			if (defined($id) && -e "$dir/$id.$suffix") {
				return "$dir/$id.$suffix";
			}
			# Test for file named name.suffix in this dir
			if (-e "$dir/$name.$suffix") {
				return "$dir/$name.$suffix";
			}
		} else {
			# must be a file - use it
			return $dir;
		}
	}
}

sub getCutError {
	my $self = shift;
	return $self->{'cutError'};
}

sub getLog {
	my $self = shift;
	my $dir = $self->getMountPath();
	if ( -e "$dir/log") {
		return qx ( cat "$dir/log" );
	}
	return "";
}

1;
