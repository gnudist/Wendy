use strict;

package Wendy::Path;

use Moose;

has 'path' => ( is => 'rw', isa => 'Str' );

sub BUILD
{
	# actual constructor

	my $self = shift;

}

no Moose;

42;
