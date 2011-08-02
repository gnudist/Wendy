use strict;

package Wendy::Util::Db;

use Wendy::Db;

use Data::Dumper;

sub query_many
{
	my $self = shift;

	my %args = @_;


	my ( $table,
	     $fields,
	     $where,
	     $limit,
	     $offset,
	     $order,
	     $debug ) = @args{ 'Table',
			       'Fields',
			       'Where',
			       'Limit',
			       'Offset',
			       'Order',
			       'Debug' };

	my $fieldspart = "";

	if( ref $fields )
	{
		$fieldspart = join( ", ", @{ $fields } );
	} elsif( $fields )
	{
		$fieldspart = $fields;
	} else
	{
		$fieldspart = '*';
	}

	my $sql = "SELECT " .
	          $fieldspart .
		  " FROM " .
		  $table .
		  ( $where ? " WHERE " . $where : '' ) .
		  ( $limit ? ( $order ? ' ORDER BY ' . $order : '' ) . " LIMIT " . $limit : '' ) .
		  ( $offset ? " OFFSET " . $offset : '' );

	if( $debug )
	{
		return $sql;
	}

	my $sth = Wendy::Db -> prepare( $sql );

	unless( $sth -> execute() )
	{
		die Wendy::Db -> errstr();
	}

	my %outcome = ();

	while( my $data = $sth -> fetchrow_hashref() )
	{
		$outcome{ $data -> { "id" } } = $data;
	}

	$sth -> finish();

	return %outcome;
}

sub query
{

	my $self = shift;

	my %args = @_;

	my $sql = &query_many( undef, %args, Debug => 1 );

	if( $args{ 'Debug' } )
	{
		return $sql;
	}

	return Wendy::Db -> selectrow_hashref( $sql );

}

42;
