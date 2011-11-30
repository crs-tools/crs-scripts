#!/usr/bin/perl -W

print "start\n";

require RPC::XML;
require RPC::XML::Client;
use Data::Dumper;
require trackerlib2;

initTracker('login' => 'xxx', 'password' => 'xxx', 'project' => '28c3')
	or die "RPC Init-Fehler";

my @projects = getProjects();
print " Projekte auf Tracker:\n";
foreach (@projects) {
	print "  $_\n";
}

my %props = getTicketProperties(1);
foreach (keys(%props)) {
	print "  $_ = '" . $props{$_} . "'\n";
}

print "Ende\n\n";

