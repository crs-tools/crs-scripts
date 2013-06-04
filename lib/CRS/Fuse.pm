
package CRS::Fuse;

our $default = ();
$default->{'basepath'} = '/opt/crs/fuse';
$default->{'binpath'} = '/usr/bin';
$default->{'capdir'} = '/opt/crs/pieces';
$default->{'capprefix'} = 'iswision2013';
#$default->{'capprefix'} = 'iwut2012_feld';
$default->{'capprefix2capdir'} = 0; # wether or not the capprefix with parameter is appended to the capdir
$default->{'repairdir'} = '/opt/crs/repair';
$default->{'fps'} = 25;
$default->{'defaultfiles'} = 20;  # Anzahl der Schnipsel, wenn keine Anzahl gegeben wird (Standard bei 6min-Schnipsel == 2h)
$default->{'defaultpieceframes'} = 3*60*$default->{'fps'};  # Laenge eines Schnispels in Frames (Standard: 3 min.)

$default->{'debug'} = 1;

#my $introdir = '/c3mnt/intros/';
##my $outrofile = '/c3mnt/outro/outro.dv';
#my $outrofile = '';

use POSIX;
use DateTime;
use strict;

sub new {
    my $class = shift;
    my $self = {};
    bless $self;

    my $args = shift;

    # merge defaults and parameters from constructor
    my %cfg = (%{$default}, %{$args});

    foreach(keys %cfg) {
        print "setting $_='".$cfg{$_}."'\n" if defined($cfg{$_}) and defined($cfg{debug});
        $self->{$_} = $cfg{$_};
    }

    # temporary property mapping
    # TODO: remove
    $self->{basepath} = $self->{'Processing.Path.Raw'} if defined $self->{'Processing.Path.Raw'};
    $self->{capdir} = $self->{'Processing.Path.Capture'} if defined $self->{'Processing.Path.Capture'};

    return $self;
}

# start has syntax YYYY-MM-DD-hh:mm
# duration has syntax hh:mm
# paddings are given in seconds
# returns ($paddedstart, $paddedend, $paddedlength)
# with paddedstart and paddedend with syntax YYYY.MM.DD-HH_MM_SS,
# paddedlength in seconds
sub getPaddedTimes {
	my ($start, $duration, $startpadding, $endpadding, undef) = @_;
#	print "getPaddedTimes ($start, $duration, $startpadding, $endpadding)\n" if defined($self->{debug});

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
	my $enddatetime = $startdatetime->clone();
	$startdatetime->add('seconds' => -$startpadding) if (defined($startpadding) and $startpadding =~ /^-?[0-9]+$/);
	my $paddedstart = $startdatetime->ymd('.') . '-' . $startdatetime->hms('_');

	my $durationseconds = undef;
	if ($duration =~ /(\d+):(\d+)/) {
		$durationseconds = (($1 * 60) + $2) * 60;
	} else {
		print STDERR "duration has wrong format!\n";
		return undef;
	}

	$enddatetime->add('seconds' => $durationseconds);
	$enddatetime->add('seconds' => $endpadding) if (defined($endpadding) and $endpadding =~ /^-?[0-9]+$/);
	my $paddedend = $enddatetime->ymd('.') . '-' . $enddatetime->hms('_');
	my $paddedlength = ($enddatetime->epoch()) - ($startdatetime->epoch());

#	print "getPaddedTimes returns ($paddedstart, $paddedend, $paddedlength)\n" if defined($self->{'debug'});
	return ($paddedstart, $paddedend, $paddedlength);
}

sub getFuseMounts {
	my $self = shift;
	return () unless defined($self->{fuse_binary});
	my $t = qx ( mount | grep ^$self->{fuse_binary} );
	my @mounts = split("\n", $t);
	my @ret = ();
	foreach(@mounts) {
		if ($_ =~ /on\ \/[^\s]+\/(\d+)\s/) {
			push(@ret, $1);
		}
	}
	return @ret;
}

sub getMountPath {
	my ($self, $vid) = @_;
	return undef unless defined($vid);
	return $self->{basepath}."/$vid";
}

sub isVIDmounted {
	my ($self, $vid) = @_;
	return 0 unless defined($vid);
	my @t = $self->getFuseMounts();
	foreach(@t) {
		if ($_ eq $vid) {
			my $pidfile = $self->{basepath}."/$vid/pid";
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
	qx ( fusermount -u $self->{basepath}/$vid -z );
}

1;
