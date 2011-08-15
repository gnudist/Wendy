use strict;

package Wendy::Out;

use Moose;

has 'template' => ( is => 'rw', isa => 'Wendy::Template' );
has 'handler' => ( is => 'rw', isa => 'Wendy::Handler' );
has 'cached' => ( is => 'rw', isa => 'Wendy::Return' );

sub execute
{
	my $self = shift;

	# this should process template, execute handlers, etc
	# or not


	my $wendy_return = undef;

	if( my $o = $self -> cached() )
	{
		return $o;

	} elsif( my $h = $self -> handler() )
	{

		$wendy_return = $h -> execute();


	} elsif( my $t = $self -> template() )
	{

		$wendy_return =  $t -> execute();
		
	} else
	{
		die 'do not know anything else yet';
	}

	if( $wendy_return -> cache() )
	{

		unless( $wendy_return -> expires() )
		{
			if( my $t = $wendy_return -> ttl() )
			{
				$wendy_return -> expires( time() + $t );
			}
		}

		unless( $wendy_return -> expires() )
		{
			$wendy_return -> cache( 0 );
		}


	}
	return $wendy_return;

}

42;
