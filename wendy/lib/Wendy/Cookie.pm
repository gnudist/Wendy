use strict;

package Wendy::Cookie;

use Moose;

has 'holder' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

use CGI::Cookie;

sub BUILD
{
	my $self = shift;

	my %c = CGI::Cookie -> fetch();
	$self -> holder( \%c );
}

sub value
{
	my $self = shift;

	my $name = shift;

	my $rv = undef;

	if( my $t = $self -> holder() -> { $name } )
	{
		$rv = $t -> value();
	}

	return $rv;
}

no Moose;

42;
