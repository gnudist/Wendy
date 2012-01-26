# just a simples handler example so I myself wouldn't forget next time I look into all this

package localhost::test1;

use Moose;

extends 'Wendy::App';

sub app_mode_default
{
	my $self = shift;

	my $core = $self -> core();

	my $tpl = Wendy::Template -> new( 
					  path => 'test_template' );

	$tpl -> add_replace( 'TEST_REPLACE' => $self -> url_only_str() );

	my $rv = $tpl -> execute();

	$rv -> cache( 0 );

	return $rv;


}


42;
