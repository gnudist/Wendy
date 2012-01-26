use strict;

package Wendy::Util::List;

require Exporter;

our @ISA         = qw( Exporter );
our @EXPORT      = qw( in );
our @EXPORT_OK   = @EXPORT;
our $VERSION     = 0.01;

sub in
{
	my ( $el, @array ) = @_;
	
	foreach ( @array )
	{
		if( $el eq $_ )
		{
			return 1;
		}
	}
	return 0;
}

42;
