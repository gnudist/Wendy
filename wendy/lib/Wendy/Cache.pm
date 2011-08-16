
use Storable ();
use Wendy::Util::File ();

package Wendy::Cache;

use Moose;

has 'file' => ( is => 'rw', isa => 'Str' );
has 'object' => ( is => 'rw', isa => 'Wendy::Return' );

sub still_valid
{
	my $self = shift;

	my $wendy_return = $self -> restore();

	if( $wendy_return -> expired() )
	{
		$self -> remove_file();
		$wendy_return = undef;
	}

	return $wendy_return;

}

sub restore
{
	my $self = shift;

	my $o = Storable::thaw( &Wendy::Util::File::slurp( $self -> file() ) );

	if( $o )
	{
		$o -> cache( 0 ); # prevent repetitive cache
		$self -> object( $o );
	}

	return $o;

}

sub remove_file
{
	my $self = shift;

	unlink $self -> file();

}

sub save
{
	my $self = shift;

	&Wendy::Util::File::save_data_in_file_atomic( Storable::freeze( $self -> object() ), $self -> file() );

}

42;
