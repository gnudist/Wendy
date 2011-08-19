use strict;
use Wendy::Return;

package Wendy::Shorts::Return;

require Exporter;

our @ISA         = qw( Exporter );
our @EXPORT      = qw( http_404 );
our @EXPORT_OK   = @EXPORT;

our $VERSION     = 0.01;

use Wendy::Db;

sub http_404
{
	my %args = @_;

	my $ret = Wendy::Return -> new( code => 404,
					data => '404 Not found',
					msg => 'Not found',
					%args );

	return $ret;

}


42;
