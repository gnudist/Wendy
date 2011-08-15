
use Storable ();
use Wendy::Util::File ();

package Wendy::Cache;

use Moose;

has 'file' => ( is => 'rw', isa => 'Str' );

sub still_valid
{
	my $self = shift;

	my $wendy_return = $self -> restore();

	$wendy_return -> cache( 0 ); # prevent repetitive cache

	if( $wendy_return -> expired() )
	{
		$wendy_return = undef;
		$self -> remove_file();
	}

	return $wendy_return;

}

sub restore
{
	my $self = shift;

	return Storable::thaw( Wendy::Util::File::slurp( $self -> file() ) );

}

sub remove_file
{
	my $self = shift;

	unlink $self -> file();

}

42;
