use strict;

use Wendy::Db;
use Wendy::Util::Db;
package Wendy::Lng;

use Moose;

has 'id' => ( is => 'rw', isa => 'Int' );
has 'name' => ( is => 'rw', isa => 'Str' );
has 'description' => ( is => 'rw', isa => 'Str' );

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
	} elsif( my $l = $self -> name() )
	{

		my $rec = Wendy::Util::Db -> query( Table => 'wendy_language',
						    Where => sprintf( 'lng=%s',
								      Wendy::Db -> quote( $l ) ) );
		if( $rec )
		{
			$self -> id( $rec -> { 'id' } );
			$self -> description( $rec -> { 'descr' } );
		} else
		{
			die sprintf( 'language %l does not exist', $l );
		}

	}

}

42;
