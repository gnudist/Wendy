use strict;

package Wendy::Util::File;

use File::Temp;
use File::Temp ':mktemp';

require Exporter;

our @ISA         = qw( Exporter );
our @EXPORT      = qw( save_data_in_file_atomic );
our @EXPORT_OK   = @EXPORT;
our $VERSION     = 0.01;

sub save_data_in_file_atomic
{
	my ( $data, $storefile ) = @_;

	my ( $tfh, $tfn ) = mkstemp( $storefile . 'XXXXX' );

	my ( $error, $success ) = ( 0, 1 );

	unless( $tfh and $tfn )
	{
		return $error;
	}
	print $tfh $data;
	close $tfh;

	my $rc = $success;
	
	unless( rename( $tfn, $storefile ) )
	{
		$rc = $error;
	}
	unlink $tfn;

	return $rc;
}

42;
