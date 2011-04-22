#!/usr/bin/perl

use strict;

package Wendy::Util::File;

use File::Temp;

require Exporter;

our @ISA         = qw( Exporter );

our @EXPORT      = qw( save_data_in_file_atomic );

our @EXPORT_OK   = @EXPORT;

our $VERSION     = 1.00;

sub save_data_in_file_atomic
{
	my ( $data, $storefile ) = @_;

	my ( $tfh, $tfn ) = tmpnam();

	my ( $error, $success ) = ( 0, 1 );

	unless( $tfh and $tfn )
	{
		return $error;
	}
	print $tfh $data;
	close $tfh;
	
	unless( rename( $tfn, $storefile ) )
	{
		return $error;
	}
	return $success;
}

1;
