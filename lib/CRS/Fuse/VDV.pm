
package CRS::Fuse::VDV;

use Data::Dumper;
use POSIX;
use Math::Round;
use strict;
use parent qw(CRS::Fuse);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);

    # set binary name
    $self->{'fuse_binary'} = 'fuse-vdv';
    $self->{'framesize'} = 144000;
    $self->{'framesize'} = $self->{'Capture.DVFrameSize'} if defined $self->{'Capture.DVFrameSize'};

    return bless($self);
}

sub getSourceFileLengthInSeconds {
	my $self = shift;
	my $filepath = shift;
	my @files = qx ( ls "$filepath"* );
	my $filesize = 0;
	foreach (@files) {
		my $file = $_;
		chop $file;
		$filesize += 0 + -s $file;
	}
	return round($filesize / ( $self->{'framesize'} * $self->{'fps'}));
}

sub checkCut {
	my $self = shift;
	my $vid = shift;
	return 0 unless defined($vid);
	return 0 unless $self->isVIDmounted($vid);
	my $p = $self->getMountPath($vid);
	print "checking mark IN of event $vid\n" if defined($self->{debug});
	my $t = qx ( cat "$p/inframe" );
	return 0 unless defined($t) && ($t > 0);
	print "checking mark OUT of event $vid\n" if defined($self->{debug});
	$t = qx ( cat "$p/outframe" );
	return 0 unless defined($t) && ($t > 0);
	print "checking virtual files of event $vid\n" if defined($self->{debug});
	$t = "$p/cut-complete.dv";
	return 0 unless (-f$t);
	### TODO verfuegbarkeit des quellmaterials pruefen -> erweiterung von fuse-vdv
	return 1;
}

sub doFuseMount {
	my $self = shift;
	my $vid = shift;
	my $room = shift;
	my $starttime = shift;
	my $length = shift;
	
	return unless defined($starttime);
	$self->doFuseUnmount($vid) if $self->isVIDmounted($vid);
	$length = $self->defaultlength unless defined($length);

	my $intro = $self->getIntro('dv', $vid);
	my $outro = $self->getOutro('dv', $vid);
	my $prefix = $self->{'Processing.Path.CaptureFilePrefix'};
	$prefix = '' unless defined($prefix);
	$prefix .= $room;

	my $capdir = $self->getCapturePath($room);
	return 0 unless defined($capdir);

	my $p = $self->getMountPath($vid);
	print "creating mount path \"$p\"\n" if defined($self->{debug});
	my $log = join "\n", qx ( mkdir -p "$p" 2>&1);

	my $fusecmd = " $self->{binpath}/$self->{'fuse_binary'} p=\"${prefix}-\" c=\"$capdir\" st=\"$starttime\" ot=$length ";
	# check existence of intro and outro
	if (defined($intro) && -e $intro ) {
		$fusecmd .= " intro=\"$intro\" ";
	}
	if (defined($outro) && -e $outro ) {
		$fusecmd .= " outro=\"$outro\" ";
	}
	$fusecmd .= " -s -oallow_other,use_ino \"$p\" ";
	print "FUSE cmd: $fusecmd\n" if defined($self->{debug});
	$log .= join "\n", qx ( $fusecmd 2>&1 );
	return ($self->isVIDmounted($vid), $log, $fusecmd);
}

sub doFuseRepairMount {
	my $self = shift;
	my $vid = shift;
	my $replacement = shift;

	print "doFuseRepairMount: $vid '$replacement'\n" if defined($self->{debug});

	return 0 unless defined($replacement) and ($replacement ne '');
	die "ERROR: no Processing.Path.Repair specified!\n" unless defined $self->{'Processing.Path.Repair'};
	my $repairdir = $self->{'Processing.Path.Repair'};

	my $replacementfullpath = "repairdir/$replacement";
	my $replacementfulldir = $repairdir;
	my $replacementfilename = $replacement;
	# support relative paths in replacement property
	if ($replacement =~ /^([^\/].*)\/([^\/]+)$/) {
		$replacementfulldir = "$repairdir/$1";
		$replacementfilename = $2;
	}
	# support absolute paths in replacement property
	if ($replacement =~ /^(\/.*)\/([^\/]+)$/) {
		$replacementfullpath = $replacement;
		$replacementfulldir = $1;
		$replacementfilename = $2;
	}

	print "checking existence of '$replacementfullpath'\n" if defined($self->{debug});
	return 0 unless -e $replacementfullpath;

	print "(re)mounting FUSE with repaired file $replacementfullpath*\n" if defined($self->{debug});
	$self->doFuseUnmount($vid) if $self->isVIDmounted($vid);


	my $length = $self->getSourceFileLengthInSeconds($replacementfullpath);
	my $intro = $self->getIntro('dv', $vid);
	my $outro = $self->getOutro('dv', $vid);

	print "mounting FUSE: id=$vid source=$replacementfullpath length=$length\n" if defined($self->{debug});
        my $p = $self->getMountPath($vid);
	my $log = join "\n", qx ( mkdir -p "$p" 2>&1 );
	my $fusecmd = $self->{binpath} . '/' . $self->{'fuse_binary'} . " st=\"$replacementfilename\" c=\"$replacementfulldir\" ot=$length ";
	# check existence of intro and outro
	if (defined($intro) && -e $intro ) {
		$fusecmd .= " intro=\"$intro\" ";
	}
	if (defined($outro) && -e $outro ) {
		$fusecmd .= " outro=\"$outro\" ";
	}
	$fusecmd .= " -s -oallow_other,use_ino \"$p\" ";
	print "FUSE cmd: $fusecmd\n" if defined($self->{debug});
	$log .= join "\n", qx ( $fusecmd 2>&1 );
	return ($self->isVIDmounted($vid), $log, $fusecmd);
}

sub getCutmarks {
	my ($self,$vid, undef) = @_;
	return undef unless defined($vid);
	return undef unless $self->isVIDmounted($vid);
	my $p = $self->getMountPath($vid);
	print "getting mark IN of event $vid: " if defined($self->{debug});
	my $i = qx ( cat "$p/inframe" );
	chop($i);
	print "$i\ngetting mark OUT of event $vid: " if defined($self->{debug});
	my $o = qx ( cat "$p/outframe" );
	chop($o);
	print "$o\n" if defined($self->{debug});

	return ($i, $o, ($i / $self->{fps}), ($o / $self->{fps}));
}

1;
