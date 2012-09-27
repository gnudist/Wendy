#!/usr/bin/perl

use strict;

package Wendy::Util::Perl;

require Exporter;

our @ISA         = qw( Exporter );
our @EXPORT      = qw( perl_module_available );

our @EXPORT_OK   = @EXPORT;
our %EXPORT_TAGS = ( default => [ qw( ) ] );
our $VERSION     = 1.00;

sub perl_module_available
{
	my $name = shift;
	
	my $file = $name . ".pm";
	my $delim = '/';
	$file =~ s{::}{$delim}g;
	eval { require $file };

	my $rv = 0;

	unless( $@ )
	{
		$rv = 1;
		
	}
	return $rv;
}

42;
