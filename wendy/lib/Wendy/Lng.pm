use strict;

package Wendy::Lng;

use Moose;

has 'id' => ( is => 'rw', isa => 'Int', required => 1 );
has 'name' => ( is => 'rw', isa => 'Str' );
has 'description' => ( is => 'rw', isa => 'Str' );

use Wendy::Util::Db;

sub BUILD
{
	# actual constructor

	my $self = shift;

	if( my $id = $self -> id() )
	{
		my $rec = Wendy::Util::Db -> query( Table => 'wendy_language',
						    Where => sprintf( 'id=%d', $id ) );
		if( $rec )
		{
			$self -> name( $rec -> { 'lng' } );
			$self -> description( $rec -> { 'descr' } );
		} else
		{
			die sprintf( 'language %d does not exist', $id );
		}
	}

	

}

42;
