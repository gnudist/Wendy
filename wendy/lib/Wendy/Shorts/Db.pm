# handy shortcuts for everyday use!

use strict;

package Wendy::Shorts::Db;
require Exporter;

our @ISA         = qw( Exporter );
our @EXPORT      = qw( dbq );
our @EXPORT_OK   = @EXPORT;

our $VERSION     = 0.01;

use Wendy::Db;

sub dbq
{
	my $v = shift;

	return Wendy::Db -> quote( $v );

}

1;
