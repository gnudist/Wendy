
package %DEFAULT_HOST_PACKAGE%::admin;

use Moose;

extends 'Wendy::Handler';

sub wendy_handler
{
	my $self = shift;

	my $core = $self -> core();


	return Wendy::Return -> new( data => 't' );


}

42;
