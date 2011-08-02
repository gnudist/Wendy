#!/usr/bin/perl

# first, lets break things

package WendyHandler;

use strict;

use Wendy::Core;

sub handler 
{
	my $r = shift;

	my $wendy = Wendy::Core -> new( mod_perl_req => $r );

	my $wendyout = $wendy -> auto_output();

	my $rv = $wendyout -> execute();

	return $wendy -> mod_perl_return( $rv );
}



1;
