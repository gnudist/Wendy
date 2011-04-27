#!/usr/bin/perl

use strict;

package Wendy::Util::String;

require Exporter;

our @ISA         = qw( Exporter );

our @EXPORT      = qw( despace );

our @EXPORT_OK   = @EXPORT;

our $VERSION     = 1.00;

sub despace
{
	my $s = shift;

	$s =~ s/^[\s\x0d\x0a]+//g;
	$s =~ s/[\s\x0d\x0a]+$//g;
	
	return $s;
}

1;
