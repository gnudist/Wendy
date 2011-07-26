#!/usr/bin/perl

# first, lets break things

package WendyHandler;

use strict;

use Wendy::Core;

sub handler 
{
	my $r = shift;

	my $wendy = Wendy::Core -> new( mod_perl_req => $r );

	my $wendyout = $wendy -> output();

	$wendyout -> load_macros();

	my $wendyrv = $wendyout -> finish();

	return $wendy -> mod_perl_return( $wendyrv );
}



1;
