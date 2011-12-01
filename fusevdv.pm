#!/usr/bin/perl -W

my $basepath = "/c3mnt/fuse/";
my $mountpath = "/c3mnt/fuse/";
my $binpath = "/usr/bin/";
my $capdir = "/c3mnt/pieces/";
my $capprefix = "feld";
my $defaultlength = 7200;  # Laenge des gefusten Videos (vorm Schnitt) in Sekunden, falls kein konkreter Wert bekannt ist
my $introdir = "/c3mnt/intros/";
my $outrofile = "/c3mnt/outro/outro.dv";

#my $debug = undef;
my $debug = "x";

use Data::Dumper;
use POSIX;
use DateTime::Format::Strptime;



# start has syntax YYYY-MM-DD-hh:mm
# duration has syntax hh:mm
# paddings are given in seconds
# returns ($paddedstart, $paddedend, $paddedlength)
# with paddedstart and paddedend with syntax YYYY.MM.DD-HH_MM_SS,
# paddedlength in seconds
sub getPaddedTimes {
	my ($start, $duration, $startpadding, $endpadding, undef) = @_;
	print "getPaddedTimes ($start, $duration, $startpadding, $endpadding)\n" if defined($debug);

	my $parser = DateTime::Format::Strptime->new('pattern' => '%Y-%m-%d-%H:%M', 'locale' => 'de_DE', 'time_zone' => 'Europe/Berlin');
	my $startdatetime = $parser->parse_datetime($start);
	$startdatetime->add('seconds' => -$startpadding) if (defined($startpadding) and $startpadding =~ /^-?[0-9]+$/);
	my $paddedstart = $startdatetime->ymd('.') . '-' . $startdatetime->hms('_');

	my $durationseconds = undef;
	if ($duration =~ /(\d+):(\d+)/) {
		$durationseconds = (($1 * 60) + $2) * 60;
	} else {
		print STDERR "duration has wrong format!\n";
		return undef;
	}

	my $enddatetime = $parser->parse_datetime($start);
	$enddatetime->add('seconds' => $durationseconds);
	$enddatetime->add('seconds' => $endpadding) if (defined($endpadding) and $endpadding =~ /^-?[0-9]+$/);
	my $paddedend = $enddatetime->ymd('.') . '-' . $enddatetime->hms('_');
	my $paddedlength = ($enddatetime->epoch()) - ($startdatetime->epoch());

	print "getPaddedTimes returns ($paddedstart, $paddedend, $paddedlength)\n" if defined($debug);
	return ($paddedstart, $paddedend, $paddedlength);
}

sub getFuseMounts {
	my $t = qx ( mount | grep ^fuse-vdv );
	my @mounts = split("\n", $t);
	my @ret = ();
	foreach(@mounts) {
		if ($_ =~ /on\ \/[^\ ]+(\d{4})\ /) {
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
				# FUSE must have been died
				doFuseUnmount($vid);
			}
		}
	}
	return 0;
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
	$t = "$p/cut-complete.dv";
	return 0 unless (-f$t);
	### TODO verfuegbarkeit des quellmaterials pruefen -> erweiterung von fuse-vdv
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
	my $length = shift;
	
	return if isVIDmounted($vid);
	return unless defined($starttime);
	$length = $defaultlength unless defined($length);

	my $intro = $introdir . $vid . ".dv";
	my $outro = $outrofile;

	# Raum zum gesamten Prefix machen, dazu Config-Wert verwenden
	$room = $capprefix . $room;
	print "mounting FUSE: id=$vid room=$room start=$starttime ".
		"length=$length\n" if defined($debug);
	qx ( mkdir -p $basepath/$vid );
	$fusecmd = " $binpath/fuse-vdv p=${room}- c=$capdir st=$starttime ot=$length ";
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
	$fusecmd .= " -oallow_other,use_ino $mountpath/$vid ";
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
	print "getting mark OUT of event $vid\n" if defined($debug);
	my $o = qx ( cat $p/outframe );

	my ($start, $end, undef) = getPaddedTimes ($rawstarttime, '00:00', ($i / -25), ($o / 25));
	return ($i, $o, $start, $end);
}

1;

