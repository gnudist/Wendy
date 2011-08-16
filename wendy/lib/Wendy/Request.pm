use strict;
use Wendy::Config;

package Wendy::Request;

use Moose;

has 'mod_perl_req' => ( is => 'rw', isa => 'Apache2::RequestRec' );

sub is_cacheable
{
	my $self = shift;

	my $rv = 0;

	my $conf = Wendy::Config -> cached();

	unless( $conf -> NOCACHE() )
	{
		if( $ENV{ 'REQUEST_METHOD' } eq 'GET' ) # yeah, we're simple folks
		{
			$rv = 1;
		}
	}


	return $rv;

}

sub cache_id
{
	my $self = shift;

	my @t = ( $self -> https(),
		  $ENV{ 'QUERY_STRING' } );

	return join( ':', @t );

}

sub https
{
	my $self = shift;

	my $rv = 0;

	if( $ENV{ 'HTTPS' } or $ENV{ 'HTTP_HTTPS' } )
	{
		$rv = 1;
	}

	return $rv;


}

__PACKAGE__ -> meta() -> make_immutable();

42;
