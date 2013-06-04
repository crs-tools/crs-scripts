
package CRS::Fuse::VDV;

#my $defaultlength = 7200;  # Laenge des gefusten Videos (vorm Schnitt) in Sekunden, falls kein konkreter Wert bekannt ist
#my $introdir = '/c3mnt/intros/';
##my $outrofile = '/c3mnt/outro/outro.dv';
#my $outrofile = '';
my $framesize = 144000;

out $fuse_binary = 'fuse-vdv';

use Data::Dumper;
use POSIX;
use Math::Round;
use strict;
use parent qw(CRS::Fuse);

sub getSourceFileLengthInSeconds {
	my $filepath = shift;
	my @files = qx ( ls $filepath* );
	my $filesize = 0;
	foreach (@files) {
		my $file = $_;
		chop $file;
		$filesize += 0 + -s $file;
	}
	return round($filesize / ( $framesize * $fps));
}

sub checkCut {
	my $vid = shift;
	return 0 unless defined($vid);
	return 0 unless $self->isVIDmounted($vid);
	my $p = $self->getMountPath($vid);
	print "checking mark IN of event $vid\n" if defined($debug);
	my $t = qx ( cat $p/inframe );
	return 0 unless defined($t) && ($t > 0);
	print "checking mark OUT of event $vid\n" if defined($debug);
	$t = qx ( cat $p/outframe );
	return 0 unless defined($t) && ($t > 0);
	print "checking virtual files of event $vid\n" if defined($debug);
	$t = "$p/cut-complete.dv";
	return 0 unless (-f$t);
	### TODO verfuegbarkeit des quellmaterials pruefen -> erweiterung von fuse-vdv
	return 1;
}

sub doFuseMount {
	my $vid = shift;
	my $room = shift;
	my $starttime = shift;
	my $length = shift;
	
	return unless defined($starttime);
	doFuseUnmount($vid) if isVIDmounted($vid);
	$length = $defaultlength unless defined($length);

	my $intro = $introdir . $vid . ".dv";
	my $outro = $outrofile;

	# Raum zum gesamten Prefix machen, dazu Config-Wert verwenden
	$room = $capprefix . $room;
	my $_capdir = $capdir;
	$_capdir .= $room if ($capprefix2capdir);
	print "mounting FUSE: id=$vid room=$room start=$starttime ".
		"length=$length\n" if defined($debug);
	qx ( mkdir -p $basepath/$vid );
	my $fusecmd = " $binpath/fuse-vdv p=${room}- c=$_capdir st=$starttime ot=$length ";
	# check existence of intro and outro
	if ( -e $intro ) {
		$fusecmd .= " intro=$intro ";
	} else {
		print STDERR "WARNING: intro file doesn't exist! ($intro)\n";
	}
	if ( -e $outro ) {
		$fusecmd .= " outro=$outro ";
	} else {
		print STDERR "WARNING: outro file doesn't exist! ($outro)\n";
	}
	$fusecmd .= " -s -oallow_other,use_ino $mountpath/$vid ";
	print "FUSE cmd: $fusecmd\n";
	qx ( $fusecmd );
	return isVIDmounted($vid);
}

sub doFuseRepairMount {
	my $vid = shift;
	my $room = shift;
	my $replacement = shift;

	print "XXXX $vid $room $replacement \n" if defined($debug);

	return 0 unless defined($replacement);
	my $replacementpath = $repairdir . '/' . $replacement ;
	return 0 unless -f $replacementpath.'aa';
	print "(re)mounting FUSE with repaired file $replacementpath*\n" if defined($debug);
	doFuseUnmount($vid) if isVIDmounted($vid);
	my $length = getSourceFileLengthInSeconds($replacementpath);

	my $intro = $introdir . $vid . ".dv";
	my $outro = $outrofile;

	# Raum zum gesamten Prefix machen, dazu Config-Wert verwenden
	print "mounting FUSE: id=$vid source=$replacementpath ".
		"length=$length\n" if defined($debug);
	qx ( mkdir -p $basepath/$vid );
	my $fusecmd = " $binpath/fuse-vdv p=$replacement c=$repairdir st=aa ot=$length ";
	# check existence of intro and outro
	if ( -e $intro ) {
		$fusecmd .= " intro=$intro ";
	} else {
		print STDERR "WARNING: intro file doesn't exist! ($intro)\n";
	}
	if ( -e $outro ) {
		$fusecmd .= " outro=$outro ";
	} else {
		print STDERR "WARNING: outro file doesn't exist! ($outro)\n";
	}
	$fusecmd .= " -s -oallow_other,use_ino $mountpath/$vid ";
	print "FUSE cmd: $fusecmd\n";
	qx ( $fusecmd );
	return isVIDmounted($vid);
}

sub getCutmarks {
	my ($vid, $rawstarttime, undef) = @_;
	return undef unless defined($vid);
	return undef unless isVIDmounted($vid);
	my $p = getMountPath($vid);
	print "getting mark IN of event $vid\n" if defined($debug);
	my $i = qx ( cat $p/inframe );
	chop($i);
	print "getting mark OUT of event $vid\n" if defined($debug);
	my $o = qx ( cat $p/outframe );
	chop($o);

	my ($start, $end, undef) = getPaddedTimes ($rawstarttime, '00:00', round ($i / -25), round ($o / 25));
	return ($i, $o, $start, $end);
}

1;
