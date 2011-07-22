use strict;

package Wendy::Lng;

use Moose;

has 'id' => ( is => 'rw', isa => 'Int' );
has 'name' => ( is => 'rw', isa => 'Str' );

sub BUILD
{
	# actual constructor

	my $self = shift;

}

no Moose;

42;
