use strict;

package Wendy::CGI;

use Moose;

has 'cgi' => ( is => 'rw', isa => 'CGI' );

sub BUILD
{
	my $self = shift;

	my $c = CGI -> new();
	$self -> cgi( $c );
}

sub param
{
	my $n = shift;

	return scalar $self -> cgi() -> param( $n );
}

sub upload
{
	my $n = shift;

	return scalar $self -> cgi() -> upload( $n );
}

sub vars
{
	return $self -> cgi() -> Vars();
}

no Moose;

42;
