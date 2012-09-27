use strict;

package Wendy::Compat::Lng;

use Moose;

has 'id' 	=> ( is => 'rw', isa => 'Int' );
has 'name' 	=> ( is => 'rw', isa => 'Str' );

__PACKAGE__ -> meta() -> make_immutable();

no Moose;

-1;

