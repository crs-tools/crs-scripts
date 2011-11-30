#!/usr/bin/perl -W

print "start\n";

require RPC::XML;
require RPC::XML::Client;
use Data::Dumper;
require trackerlib2;

initTracker('login' => 'XXXXXX', 'password' => 'XXXXXXX', 'project' => '28c3')
	or die "RPC Init-Fehler";

my @projects = getProjects();
print " Projekte auf Tracker:\n";
foreach (@projects) {
	print "  $_\n";
}

print "Ende\n\n";

