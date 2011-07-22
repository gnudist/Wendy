use strict;

package Wendy::Host;

use Moose;

has 'id' => ( is => 'rw', isa => 'Int' );
has 'name' => ( is => 'rw', isa => 'Str' );
has 'defaultlng' => ( is => 'rw', isa => 'Wendy::Lng' );
has 'languages' => ( is => 'rw', isa => 'ArrayRef[Wendy::Lng]' );
has 'aliases' => ( is => 'rw', isa => 'ArrayRef[Str]' );

sub BUILD
{
	# actual constructor

	my $self = shift;

}

no Moose;

42;
