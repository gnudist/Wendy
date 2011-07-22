use strict;

package Wendy::DB;

use Moose;

has 'dbh' => ( is => 'rw', isa => 'DBI::db' );

sub BUILD
{
	# actual constructor

	my $self = shift;

	# connect and stuff

}

no Moose;

42;
