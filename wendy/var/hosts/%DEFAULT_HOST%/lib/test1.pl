
package localhost::test1;

use Moose;

extends 'Wendy::Handler';

sub wendy_handler
{
	my $self = shift;

	my $core = $self -> core();

	my $tpl = Wendy::Template -> new( host => $core -> host(),
					  path => 'test_template' );

	$tpl -> add_replace( 'TEST_REPLACE' => 'This is test replace.' );

	my $rv = $tpl -> execute();

	$rv -> cache( 0 );

	return $rv;


}


42;
