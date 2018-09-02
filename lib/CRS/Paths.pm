package CRS::Paths;

use strict;

sub new {
	my $class = shift;
	my $self = {};
	bless $self;

	my $args = shift;
	foreach(keys %{$args}) {
		$self->{$_} = %{$args}{$_};
	}

	return $self;
}

sub getPath {
	my ($self, $pathname, $default, undef) = @_;

	return unless defined($pathname);
	return $self->{$pathname} if (index($pathname, ".") != -1 && defined($self->{$pathname}));
	return $self->{'Processing.Path.'.$pathname} if (defined($self->{'Processing.Path.'.$pathname}));

	return $default unless defined($self->{'Processing.BasePath'});

	my $project = $self->{'Project.Slug'};
	my $base = $self->{'Processing.BasePath'};

	if ($pathname eq 'Capture') {
		return "$base/capture/$project/";
	}
	if ($pathname eq 'Intros') {
		# TODO this is an optional path, so bailout for now
		# return "$base/intros/$project/";
	}
	if ($pathname eq 'Outro') {
		# TODO this is an optional path, so bailout for now
		# return "$base/intros/$project/outro.ts";
	}
	if ($pathname eq 'Output') {
		return "$base/encoded/$project/";
	}
	if ($pathname eq 'Raw') {
		return "$base/fuse/";
	}
	if ($pathname eq 'Repair') {
		return "$base/tmp/$project/repair/";
	}
	if ($pathname eq 'Tmp') {
		return "$base/tmp/$project/";
	}
	return $default;
}

1;
