
package localhost::root;

use Moose;

extends 'Wendy::Handler';

sub wendy_handler
{
	my $self = shift;

	my $core = $self -> core();

	return Wendy::Return -> new( data => sprintf( 'This is handler speaking. Time now is %d', time() ),
				     ttl => 10,
				     cache => 1 );


}


42;
