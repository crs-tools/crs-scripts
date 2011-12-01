#!/usr/bin/perl -W

print "start\n";

use Data::Dumper;
require trackerlib2;

# call script with these arguments in this order: hostname secret project

initTracker('hostname' => shift, 'secret' => shift, 'project' => shift);
my %projects = getProjects();
print " Projekte auf Tracker:\n";
foreach (keys(%projects)) {
	print "  $_ => $projects{$_}\n";
}

my %props = getTicketProperties(1);
foreach (keys(%props)) {
	print "  $_ = '" . $props{$_} . "'\n";
}

print "Ende\n\n";

