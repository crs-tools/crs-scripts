#!/usr/bin/perl

use strict;
use warnings;
use charnames ':full';

BEGIN { push @INC, '../tracker3.0/lib'; }

use C3TT::Client;
use File::Spec;
use Sys::Hostname;
use XML::Simple qw(:strict);
use Encode;

# convert Unicode to ASCII
sub asciify {
    my ($ord) = @_;

    # is ASCII -> change nothing
    if ($ord < 128) {
        return chr($ord);
    }
    my $name = charnames::viacode($ord);
    my ($main, $with) = $name =~ m{^(.+)\sWITH\s(.*)}o;
    if (defined $with) {
        if (($with eq 'DIAERESIS') and ($main =~ m{\b[aou]\b}oi)) {
            return chr(charnames::vianame($main)) ."e";
        }
        return chr(charnames::vianame($main));
    }
    return "ss" if ($name eq 'LATIN SMALL LETTER SHARP S');
    return "?";
}

# load job
sub load_job {

    my $jobfile = shift;
    die 'You need to supply a job!' unless $jobfile;

    my $job = XMLin(
        $jobfile,
        ForceArray => [
            'option',
            'task',
            'tasks',
        ],
        KeyAttr => ['id'],
    );
    return $job;
}

# escape/remove shell quotes
sub replacequotes {
    my ($toquote) = @_;

    # contains quotes
    if ($^O eq 'linux') {
        # escape them on Linux
        $toquote =~ s{"}{\\"}og;
    } else {
        # strip them
        $toquote =~ s{"}{}og;
    }

    return $toquote;
}

# create command 
sub parse_cmd {
    my ($options, $encode) = @_;

    my $cmd = '';
    my $filerr = 0;

    CONSTRUCT: foreach my $option (@$options) {
        my $cmdpart = '';
        if (ref \$option ne 'SCALAR') {
            if ($option->{filetype}) {
                # check locations and re-write file name 
		# XXX FIXME TODO das sollte lieber raus, aber ordentlich testen vorher. 
		# oder in check_file auslagern und verschiedene varianten pruefen
                my $name = encode('ascii', $option->{content}, \&asciify);
                $cmdpart = $name;
            } else {
                # check for quoting option
                if (defined($option->{'quoted'}) && $option->{'quoted'} eq 'no') {
                    $cmd .= ' ' . $option->{content} . ' ';
                } else {
                    # just copy value
                    $cmdpart = $option->{content};
                }
            }
        } else {
            $cmdpart = $option
        }
        next unless defined($cmdpart);

        if ($cmdpart =~ m{[ \[\]\(\)\|]}o) {
            # escape or remove existing quotes
            $cmdpart = replacequotes($cmdpart) if $cmdpart =~ m{"}o;
            # replace $ in cmds
            $cmdpart =~ s/\$/\\\$/g;
            # quote everything with regular double quotes
            if ($cmd =~ m{=$}o) {
                $cmd .= '"'. $cmdpart .'"';
            } else {
                $cmd .= ' "'. $cmdpart .'"';
            }
        } else {
            $cmdpart = replacequotes($cmdpart) if $cmdpart =~ m{"}o;
            if ($cmd =~ m{=$}o) {
                $cmd .= $cmdpart;
            } else {
                $cmd .= ' '. $cmdpart;
            }
        }
    }

    $cmd =~ s{^ }{}o;

    return $cmd;
}


sub task_print {
    my ($job, $filter) = @_;

    my @tasks = ( ) ;
    foreach(@{$job->{tasks}}) {
        foreach(@{$_->{task}}) {
            push @tasks, $_ if $_->{type} eq $filter;
        }
    }

    my $locenc = $ENV{'LANG'};
    $locenc = $ENV{'LC_ALL'} if $ENV{'LC_ALL'};
    (undef, $locenc) = split(m{\.}o, $locenc);
    $locenc = 'ascii' unless $locenc;
    $locenc = 'utf-8' if 'utf8' eq lc $locenc;

    TASK: for (my $task_id = 0; $task_id < @tasks; ++$task_id) {
        next TASK if (defined($filter) and $tasks[$task_id]->{type} ne $filter);

        # parse XML and print cmd
        my $cmd = encode($locenc,
            parse_cmd ($tasks[$task_id]->{option}, $tasks[$task_id]->{meta_encoding}));

        print "Cmd #$task_id:\n\n$cmd\n\n";
    }
}

### main

my ($host)     = split(m{\.}o, Sys::Hostname::hostname(), 2);
my $base_url   = $ENV{'CRS_TRACKER'};
my $token      = $ENV{'CRS_TOKEN'};
my $password   = $ENV{'CRS_SECRET'};
my $ticketid   = $ARGV[0];
my $jobtype    = $ARGV[1];
$jobtype = 'encoding' unless defined($jobtype);

if (!defined($ticketid)) {
    print "\n\nUsage:\n\tperl get-commands.pl <ticket ID> [job type]\n\n\tRemember, the ticket ID is NOT the Fahrplan ID!\n\tjob type defaults to 'encoding'\n\n\n";
    exit 1;
}

my $tracker = C3TT::Client->new($base_url, $token, $password) or die "Cannot init tracker";
my $jobxml = $tracker->getJobfile($ticketid);
utf8::encode($jobxml);  # sometimes necessary, sometimes not

my $filter = '';
my $job = load_job($jobxml);
task_print($job, $jobtype);
print "\n\n\nDone.\n\n";

