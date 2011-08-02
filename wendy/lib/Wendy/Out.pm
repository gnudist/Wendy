use strict;

package Wendy::Out;

use Moose;

has 'template' => ( is => 'rw', isa => 'Wendy::Template' );

sub execute
{
	my $self = shift;

	# this should process template, execute handlers, etc
	# or not




	if( my $t = $self -> template() )
	{

		return $t -> execute();
		
	} else
	{
		die 'do not know anything else yet';
	}


}

42;
