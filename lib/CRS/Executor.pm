package CRS::Executor;

=head1 NAME

CRS::Executor - Library for executing Tracker XML Jobfiles

=head1 VERSION

Version 1.0

=head1 SYNOPSIS

Generic usage:

    use CRS::Executor;
    my $executor = new CRS::Executor($jobxml);
    $ex->execute();

=head1 DESCRIPTION

The CRS tracker uses a well-defined XML schema to describe commands that shall be executed by workers.
This library "unpacks" those XML job files and actually executes the commands, thereby handling things
like managing input and output files and directories, correct encoding etc.

=head1 METHODS

=head2 new ($jobfile)

Create a new instance, giving it an XML jobfile. The parameter can be either a string containing XML or
a string containing the absolute full path to an XML file.

=head2 execute ($jobtype)

Actually execute the commands described in the XML jobfile. The optional jobtype argument can be used to
execute other tasks than the default jobtype of 'encoding'.

Returns undef on error (or dies on fatal error), returns 1 if all tasks were executed successfully.

=head2 getOutput ()

Returns the output of the executed commands together with informational output from the library as array.

=head2 getErrors ()

Returns the errors of the library.

=cut

use strict;
use warnings;
use charnames ':full';

use File::Spec;
use File::Which qw(which);
use XML::Simple qw(:strict);
use Encode;

use constant FILE_OK => 0;

sub new {
	shift;
	my $jobxml = shift;
	my $self;

	$self->{jobxml} = $jobxml;
	$self->{job} = load_job($jobxml);

	# do not create instance if jobxml is faulty
	return unless defined $self->{job};

	$self->{locenc} = 'ascii';
	$self->{locenc} = `locale charmap`;
	$self->{bogusmode} = 0;
	
	$self->{outfilemap} = {};
	$self->{tmpfilemap} = {};
	$self->{output} = [];
	$self->{errors} = [];

	bless $self;
	return $self;
}

sub print {
	my ($self, $text) = @_;
	push @{$self->{output}}, $text;
	print "$text\n";
}

sub error {
	my ($self, $text) = @_;
	push @{$self->{errors}}, $text;
	print STDERR "$text\n";
}

sub fatal {
	my ($self, $text) = @_;
	push @{$self->{errors}}, $text;
	die "$text\n";
}

# static method, convert Unicode to ASCII, as callback from Encode
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

# static method, load job XML into object
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

# static method, escape/remove shell quotes
sub replacequotes {
    my ($toquote) = @_;

    # contains quotes
    if ($^O eq 'linux') {
        # escape them on Linux
        $toquote =~ s{'}{'\\''}og;
    } else {
        # strip them
        $toquote =~ s{"}{}og;
    }

    return $toquote;
}

# search a file
sub check_file {
	my ($self, $name, $type) = @_;

	return ($name, FILE_OK) if $self->{bogusmode} eq 1;

	# executable lookup
	if ($type eq 'exe') {
		return ($name, FILE_OK) if -x $name;
		my $path = which $name;
		$self->fatal ("Executable $name cannot be found!") unless defined($path);
		$self->fatal ("Executable $name is not executable!") unless -x $path;
		return ($name, FILE_OK);
	}

	my $alternateName = $name;
	my $protocol;
	# all other files must be given with absolute paths:
	if (not File::Spec->file_name_is_absolute($name)) {
		if ($name =~ /^(.+:)([^:]+)$/) { # try URL style, e.g. for FFmpeg input syntax
			$protocol = $1;
			$alternateName = $2;
		} elsif ($name =~ /^~/) { # expand leading ~ to users home directory
			$name =~ s/^~(\w*)/ ( getpwnam( $1 || $ENV{USER} ))[7] /e;
			$alternateName = $name;
		}
		if (not File::Spec->file_name_is_absolute($alternateName)) {
			$self->fatal ("Non-absolute filename given: '$protocol$name'!");
		}
	}

	# input and config files must exist
	if ($type eq 'in' or $type eq 'cfg') {
		return ($name, FILE_OK) if -r $name or -r $alternateName;

		# maybe it is a file that is produced during this execution?
		if (defined($self->{outfilemap}->{$name})) {
			return ($self->{outfilemap}->{$name}, FILE_OK);
		}
		if (defined($self->{outfilemap}->{$alternateName})) {
			return ($protocol.$self->{outfilemap}->{$alternateName}, FILE_OK);
		}
		# try harder to find: asciify filename
		$name = encode('ascii', $name, \&asciify);
		return ($name, FILE_OK) if -r $name;

		$self->fatal ("Fatal: File $protocol$alternateName is missing!") if defined($protocol);
		$self->fatal ("Fatal: File $name is missing!");
	}

	# output files must not exist. if they do, they are deleted and deletion is checked
	if ($type eq 'out' || $type eq 'tmp') {
		if (-e $name) {
			$self->print ("Output or temporary file exists: '$name', deleting file.");
			unlink $name;
			$self->fatal ("Cannot delete '$name'!") if -e $name;
		}
		# check that the directory of the output file exists and is writable. if it
		# does not exist, try to create it.
		my(undef,$outputdir,undef) = File::Spec->splitpath($name);
		if (not -d $outputdir) {
			$self->print ("Output path '$outputdir' does not exist, trying to create");
			qx ( mkdir -p $outputdir );
			$self->fatal ("Cannot create directory '$outputdir'!") if (not -d $outputdir);
		}
		$self->fatal ("Output path '$outputdir' is not writable!") unless (-w $outputdir or -k $outputdir);

		# store real output filename, return unique temp filename instead
		if (defined($self->{outfilemap}->{$name})) {
			return ($self->{outfilemap}->{$name}, FILE_OK);
		}
		if (defined($self->{tmpfilemap}->{$name})) {
			return ($self->{tmpfilemap}->{$name}, FILE_OK);
		}
		my $safety = 10;
		do {
			my $tempname = $name . '.' . int(rand(32767));
			$self->{outfilemap}->{$name} = $tempname if $type eq 'out';
			$self->{tmpfilemap}->{$name} = $tempname if $type eq 'tmp';
			return ($tempname, FILE_OK) unless -e $tempname;
		} while ($safety--);
		$self->fatal ("Unable to produce random tempname!");
	}

	# do not allow unknown filetypes
	$self->fatal ("Unknown file type in jobfile: $type");
}

# create command 
sub parse_cmd {
	my ($self, $options) = @_;

	my $cmd = '';
	my $filerr = 0;
	my @outfiles;

	CONSTRUCT: foreach my $option (@$options) {
		my $cmdpart = '';
		if (ref \$option ne 'SCALAR') {
			if ($option->{filetype}) {
				# check locations and re-write file name 
				my $type = $option->{filetype};
				my $error;
				($cmdpart, $error) = $self->check_file($option->{content}, $type);

				# remember file problems
				$filerr = $error if $error;
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

		if ($cmdpart =~ m{[ \[\]\(\)\s\|]}o) {
			# escape or remove existing quotes
			$cmdpart = replacequotes($cmdpart) if $cmdpart =~ m{'}o;
			# quote everything
			if ($cmd =~ m{=$}o) {
				$cmd .= "'". $cmdpart ."'";
			} else {
				$cmd .= " '". $cmdpart ."'";
			}
		} else {
			$cmdpart = replacequotes($cmdpart) if $cmdpart =~ m{'}o;
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

sub run_cmd {
	my ($self, $cmd, $cmdencoding) = @_;

	# set encoding on STDOUT so program output can be re-printed without errors
	binmode STDOUT, ":encoding($self->{locenc})";

	$self->print ("running: \n$cmd\n\n");
	# The encoding in which the command is run is configurable, e.g. you want 
	# utf8 encoded metadata as parameter to FFmpeg also on a non-utf8 shell.
	$cmdencoding = 'UTF-8' unless defined($cmdencoding);
	$cmd = encode($cmdencoding, $cmd);

	my $handle;
	open ($handle, '-|', $cmd . ' 2>&1') or $self->fatal ("Cannot execute command");
	while (<$handle>) {
		my $line = decode($cmdencoding, $_);
		print $line;
		chomp $line;
		push @{$self->{output}}, $line;
	}
	close ($handle);

	# reset encoding layer
	binmode STDOUT;

	# check return code
	if ($?) {
		$self->print ("Task exited with code $?");
		return 0;
	}
	return 1;
}

sub task_loop {
	my $self = shift;

	my @tasks = ( ) ;
	foreach(@{$self->{job}->{tasks}}) {
		foreach(@{$_->{task}}) {
			push @tasks, $_ if $_->{type} eq $self->{filter};
		}
	}

	my $num_tasks = scalar @tasks;
	my $successful = 1;
	TASK: for (my $task_id = 0; $task_id < $num_tasks; ++$task_id) {

		# parse XML and print cmd
		my $cmd = $self->parse_cmd($tasks[$task_id]->{option});
		$self->print ("now executing task " . ($task_id + 1) . " of $num_tasks");

		$successful = $self->run_cmd($cmd, $tasks[$task_id]->{encoding});
		#check output files for existence if command claimed to be successfull
		if ($successful) {
			foreach (keys %{$self->{outfilemap}}) {
				next if -e $self->{outfilemap}->{$_};
				$successful = 0;
				$self->print ("output file missing: $_");
			}
		}

		# call hook
		if ($successful && defined($self->{precb})) {
			$successful = $self->{precb}->($self);
			if ($successful == 0) {
				# abort, but don't delete files
				$self->error('preTaskComplete callback signaled termination');
				last;
			}
		}

		#rename output files to real filenames after successful execution, delete them otherwise
		foreach (keys %{$self->{outfilemap}}) {
			my ($src, $dest) = ($self->{outfilemap}->{$_},$_);
			if ($successful > 0) {
				$self->print ("renaming '$src' to '$dest'");
				rename ($src, $dest);
			} else {
				$self->print ("deleting '$src'");
				unlink $src;
			}
			delete ($self->{outfilemap}->{$_});
		}

		last unless $successful > 0;
	}
	#delete other temporary files
	foreach (keys %{$self->{tmpfilemap}}) {
		unlink $self->{tmpfilemap}->{$_};
		# dirty hack for FFmpeg files
		unlink $self->{tmpfilemap}->{$_} . '-0.log';
		delete ($self->{tmpfilemap}->{$_});
	}
	return $successful > 0;
}

sub execute {
	my ($self, $filter) = @_;

	$self->{filter} = $filter if defined($filter);
	$self->{filter} = 'encoding' unless defined($filter);
	return $self->task_loop();
}

sub printParsedCommands {
	my $self = shift;

	$self->{bogusmode} = 1;

	my @tasks = ( ) ;
	foreach(@{$self->{job}->{tasks}}) {
		foreach(@{$_->{task}}) {
			push @tasks, $_;
		}
	}

	my $num_tasks = scalar @tasks;
	TASK: for (my $task_id = 0; $task_id < $num_tasks; ++$task_id) {

		# parse XML and print cmd
		my $cmd = $self->parse_cmd($tasks[$task_id]->{option});
		$self->print ("task " . ($task_id + 1) . " (type ". $tasks[$task_id]->{type} .") of $num_tasks has command:\n\n$cmd\n\n");
	}
	$self->{bogusmode} = 0;
}

sub getOutput {
	my $self = shift;
	return @{$self->{output}};
}

sub getErrors {
	my $self = shift;
	return @{$self->{errors}};
}

=head2 setPreTaskFinishCallback (sub reference)

Register a callback that is called after a task has been finished but before the output files 
are renamed to their actual names. The callback gets one parameter, the calling Executor instance.

The return value of this callback is important.
If it returns 1, execution continues.
If it returns 0, execution will not continue.
If it returns -1, execution will not continue and the temporary output files are deleted.

=cut

sub setPreTaskFinishCallback {
	my $self = shift;
	my $cb = shift;
	unless (ref $cb) {
		$self->error("not a callback reference: ".Dumper($cb));
		return;
	}
	$self->{precb} = $cb;
}

=head2 getTemporaryFiles ()

This method returns an array containing all absolute full paths of the temporary 
files that have been created in the execution phase.

=cut

sub getTemporaryFiles {
	my $self = shift;
	my @ret = ();

	foreach (keys %{$self->{outfilemap}}) {
		push @ret, $self->{outfilemap}->{$_};
	}
	return @ret;
}

=head1 JOBFILE FORMAT

There must be a <job> tag as document root element.

A job element contains one 'tasks' element describing one or more tasks.  Every
task is made up of options.  Those options are changed by the Executor if they
are marked as being filenames, but finally get concatenated to a cmd line which 
is executed.  Multiple tasks of the same type are executed in the order they
appear in the XML.

Make sure you mark every input and output file with 'filetype="in"', 'filetype="tmp"' or
'filetype="out"', so the program can check for existence of those files, the containing
folders, map them to temporary names and so on.  All paths of files MUST be absolute.
The filetype 'cfg' is accepted for backward compatibility, but treated exactly like
filetype 'in'.

You don't need to quote an option.  This will be done automagically if
the option's value contains whitespace characters. You can override this
behaviour by including an attribute quoted="no" in the option element.

       <?xml version="1.0"?>
        <job>
          <tasks>
            <task type="encoding">
              <option filetype="exe">ffmpeg</option>
              <option>-i</option>
              <option filetype="in">/path/to/src</option>
              <option quoted="no">| x264</option>
              <option>-preset</option>
              <option filetype="cfg">/path/to/preset</option>
              <option>&gt;</option>
              <option filetype="out">file-x264</option>
            </task>

            <task type="tagging">
              <option filetype="exe">AtomicParsely</option>
              <option>-i</option>
              <option filetype="in">file-x264</option>
              <option>-o</option>
              <option filetype="out">/dest/outfile</option>
              <option>-author</option>
              <option>John Doe</option>
              <option>-title</option>
              <option>Foo Bar</option>
            </task>
          </tasks>

        </job>

=cut
1;
