#!/usr/bin/perl -W

my $basepath = '/opt/crs/fuse/';
my $mountpath = '/opt/crs/fuse/';
my $binpath = '/usr/bin/';
my $capdir = '/opt/crs/storage/pieces/';
my $capprefix = 'saal';
my $capprefix2capdir = 1; # wether or not the capprefix with parameter is appended to the capdir
my $repairdir = '/opt/crs/storage/repaired';
my $fps = 25;
my $defaultfiles = 20;  # Anzahl der Schnipsel, wenn keine Anzahl gegeben wird (Standard bei 6min-Schnipsel == 2h)
my $defaultpieceframes = 6*60*$fps;  # Laenge eines Schnispels in Frames (Standard: 6 min.)

my $debug = undef;

use Data::Dumper;
use POSIX;
use DateTime;
use Math::Round;
use strict;



# start has syntax YYYY-MM-DD-hh:mm
# duration has syntax hh:mm
# paddings are given in seconds
# returns ($paddedstart, $paddedend, $paddedlength)
# with paddedstart and paddedend with syntax YYYY.MM.DD-HH_MM_SS,
# paddedlength in seconds
sub getPaddedTimes {
	my ($start, $duration, $startpadding, $endpadding, undef) = @_;
	print "getPaddedTimes ($start, $duration, $startpadding, $endpadding)\n" if defined($debug);

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

	print "getPaddedTimes returns ($paddedstart, $paddedend, $paddedlength)\n" if defined($debug);
	return ($paddedstart, $paddedend, $paddedlength);
}

sub getFuseMounts {
	my $t = qx ( mount | grep ^fuse-ts );
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
	my $vid = shift;
	return undef unless defined($vid);
	return "$basepath/$vid";
}

sub isVIDmounted {
	my $vid = shift;
	return 0 unless defined($vid);
	my @t = getFuseMounts;
	foreach(@t) {
		if ($_ eq $vid) {
			my $pidfile = "$basepath/$vid/pid";
			if (-f$pidfile) {
				return 1;
			} else {
				# FUSE seems to be gone
				doFuseUnmount($vid);
			}
		}
	}
	return 0;
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
		my $size = qx ( ffprobe $file | grep Duration: );
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
	my $vid = shift;
	return 0 unless defined($vid);
	return 0 unless isVIDmounted($vid);
	my $p = getMountPath($vid);
	print "checking mark IN of event $vid\n" if defined($debug);
	my $t = qx ( cat $p/inframe );
	return 0 unless defined($t) && ($t > 0);
	print "checking mark OUT of event $vid\n" if defined($debug);
	$t = qx ( cat $p/outframe );
	return 0 unless defined($t) && ($t > 0);
	print "checking virtual files of event $vid\n" if defined($debug);
	$t = "$p/uncut.ts";
	return 0 unless (-f$t);
	### TODO verfuegbarkeit des quellmaterials pruefen -> erweiterung von fuse-ts
	return 1;
}

sub doFuseUnmount {
	my $vid = shift;
	return unless defined ($vid);
	qx ( /usr/bin/fusermount -u $basepath/$vid );
}

sub doFuseMount {
	my $vid = shift;
	my $room = shift;
	my $starttime = shift;
	my $length = shift; # length in seconds
	
	return unless defined($starttime);
	doFuseUnmount($vid) if isVIDmounted($vid);
	my $files;
	if (defined($length)) {
		$files = ($length / $defaultpieceframes) + 1;
	} else {
		$files = $defaultfiles;
	}
	my $frames = $length * $fps;

	# Raum zum gesamten Prefix machen, dazu Config-Wert verwenden
	$room = $capprefix . $room;
	my $_capdir = $capdir;
	$_capdir .= $room if ($capprefix2capdir);
	print "mounting FUSE: id=$vid room=$room start=$starttime ".
		"numfiles=$files totalframes=$frames\n" if defined($debug);
	qx ( mkdir -p $basepath/$vid );
	my $fusecmd = " $binpath/fuse-ts p=${room}- c=$_capdir st=$starttime numfiles=$files totalframes=$frames ";
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
	my ($files,$length) = getSourceFileLengthInSeconds($replacementpath);
	my $frames = $length * $fps;

	# Raum zum gesamten Prefix machen, dazu Config-Wert verwenden
	print "mounting FUSE: id=$vid source=$replacementpath \n" if defined($debug);
	qx ( mkdir -p $basepath/$vid );
	my $fusecmd = " $binpath/fuse-ts p=$replacement c=$repairdir st=aa numfiles=$files totalframes=$frames ";
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
	print "getting mark IN of event $vid\n" if defined($debug);
	my $it = qx ( cat $p/intime );
	chop($it);
	print "getting mark OUT of event $vid\n" if defined($debug);
	my $ot = qx ( cat $p/outtime );
	chop($ot);

	my ($start, $end, undef) = getPaddedTimes ($rawstarttime, '00:00', round ($i / -$fps), round ($o / $fps));
	return ($i, $o, $start, $end, $it, $ot);
}

1;

