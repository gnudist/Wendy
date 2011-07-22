#!/usr/bin/perl

# first, lets break things

package WendyHandler;

use strict;

use Wendy::Core;

sub handler 
{
	my $r = shift;

	my $wendy = Wendy::Core -> new( req => $r );

	my $wendyout = $wendy -> output();

	my $wendyrv = $wendyout -> finish();

	return $wendy -> mod_perl_return( $wendyrv, $r );
}



1;
