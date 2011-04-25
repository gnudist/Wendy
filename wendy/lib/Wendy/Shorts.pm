#!/usr/bin/perl

use strict;

package Wendy::Shorts;
require Exporter;

our @ISA         = qw( Exporter );
our @EXPORT      = qw( gr ar pt pd pm lm );
our @EXPORT_OK   = @EXPORT;
our $VERSION     = 1.00;

use Wendy::Templates;

# load macros
sub lm
{
	my $addr = shift;

	return &sload_macros( $addr );
}

# get replace
sub gr
{
	my $r = shift;

	return ( &get_replace( $r ) or 'R: ' . $r );

}

# add replace
sub ar
{
	return &add_replace( @_ );
}

# process template
sub pt
{
	my $t = shift;

	my $rv = &template_process( $t );
	return $rv -> { 'data' };
}

# process data
sub pd
{
	my $data = shift;

	my $rv = &data_process( $data );
	return $rv -> { 'data' };

}

# process macros
sub pm
{
	my $m = shift;
	return &pd( &gr( $m ) );
}

1;
