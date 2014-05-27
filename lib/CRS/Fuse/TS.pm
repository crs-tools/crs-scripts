
package CRS::Fuse::TS;

use Math::Round;
use strict;
use parent qw(CRS::Fuse);

sub new {
    my ($class, @args) = @_; 
    my $self = $class->SUPER::new(@args);

    # set binary name
    $self->{fuse_binary} = 'fuse-ts';

    return bless($self);
}

sub getSourceFileLengthInSeconds {
	my $filepath = shift;
	my @files = qx ( ls $filepath* );
	my $filesecs = 0;
	my $files = 0;
	foreach (@files) {
		my $file = $_;
		chop $file;
		# Duration: 00:00:35.99
		my $size = qx ( ffprobe "$file" | grep Duration: );
		if ($size =~ /Duration:\ ([0-9]{2})\:([0-9]{2})\:([0-9]{2})\.([0-9]{2})/) {
			$size = $1 * 3600 + $2 * 60 + $3;
			$size++ if ($4 > 50);
			$filesecs += $size;
			$files++;
		}
	}
	return ($files,$filesecs);
}

sub checkCut {
	my ($self, $vid) = @_;
	return 0 unless defined($vid);
	#return 0 unless $self->isVIDmounted($vid);
	my $p = $self->getMountPath($vid);
	print "checking mark IN of event $vid\n" if defined($self->{debug});
	my $t = qx ( cat "$p/inframe" );
	chop $t;
	return 0 unless defined($t) && ($t > 0);
	print "checking mark OUT of event $vid\n" if defined($self->{debug});
	$t = qx ( cat "$p/outframe" );
	chop $t;
	return 0 unless defined($t) && ($t > 0);
	print "checking virtual files of event $vid\n" if defined($self->{debug});
	$t = "$p/uncut.ts";
	return 0 unless (-f$t);
	### TODO verfuegbarkeit des quellmaterials pruefen -> erweiterung von fuse-ts
	return 1;
}

# length in seconds
sub doFuseMount {
	my ($self, $vid, $room, $starttime, $length) = @_;
	
	return unless defined($starttime);
	$self->doFuseUnmount($vid) if $self->isVIDmounted($vid);
	my $files;
	if (defined($length)) {
		$files = int($length * $self->{fps} / $self->{defaultpieceframes}) + 1;
	} else {
		$files = $self->{defaultfiles};
		$length = $files * $self->{defaultpieceframes} / $self->{fps};
	}
	my $frames = $length * $self->{fps};

	# Raum zum gesamten Prefix machen, dazu Config-Wert verwenden
	$room = $self->{capprefix} . $room;
	my $_capdir = $self->{capdir};
	$_capdir .= $room if ($self->{capprefix2capdir});
	print "mounting FUSE: id=$vid room=$room start=$starttime ".
		"numfiles=$files totalframes=$frames\n" if defined($self->{debug});

	my $p = $self->getMountPath($vid);
	return 0 unless defined($p);
	qx ( mkdir -p "$p" );
	my $fusecmd = " ".$self->{binpath}."/fuse-ts p=\"${room}-\" c=\"$_capdir\" st=\"$starttime\" numfiles=$files totalframes=$frames ";
	$fusecmd .= " -s -oallow_other,use_ino \"$p\" ";
	print "FUSE cmd: $fusecmd\n";
	qx ( $fusecmd );
	return $self->isVIDmounted($vid);
}

sub doFuseRepairMount {
	my ($self, $vid) = @_;
	my $replacement = shift;

	print "doFuseRepairMount: $vid '$replacement'\n" if defined($self->{debug});

	return 0 unless defined($replacement);
	my $replacementpath = $self->{repairdir} . '/' . $replacement ;
	return 0 unless -f $replacementpath;
	print "replacing FUSE with repaired file $replacementpath*\n" if defined($self->{debug});
	$self->doFuseUnmount($vid) if $self->isVIDmounted($vid);
	my $p = $self->getMountPath($vid);
	return 0 unless defined($p);
	qx ( mkdir -p \"$p\" );
	qx ( ln -s "$replacementpath" \"$p/uncut.ts\" );
	return 1;
}

sub getCutmarks {
	my ($self, $vid, $rawstarttime, undef) = @_;
	return undef unless defined($vid);
	#return undef unless $self->isVIDmounted($vid);
	my $p = $self->getMountPath($vid);
	print "getting mark IN of event $vid\n" if defined($self->{debug});
	my $i = qx ( cat \"$p/inframe\" );
	chop($i);
	print "getting mark OUT of event $vid\n" if defined($self->{debug});
	my $o = qx ( cat \"$p/outframe\" );
	chop($o);
	print "getting mark IN of event $vid\n" if defined($self->{debug});
	my $it = qx ( cat \"$p/intime\" );
	chop($it);
	print "getting mark OUT of event $vid\n" if defined($self->{debug});
	my $ot = qx ( cat \"$p/outtime\" );
	chop($ot);

	my ($start, $end, undef) = CRS::Fuse::getPaddedTimes($rawstarttime, '00:00', round ($i / -$self->{fps}), round ($o / $self->{fps}));
	return ($i, $o, $start, $end, $it, $ot);
}

1;
