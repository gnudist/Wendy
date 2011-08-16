use strict;

package Wendy::Path;

use Moose;
use Moose::Util::TypeConstraints;

has 'path' => ( is => 'rw', isa => 'Str' );
has 'addr' => ( is => 'rw', isa => 'Str' );

coerce 'Str',
    from 'Wendy::Path',
    via { $_ -> path() };

coerce 'Wendy::Path',
    from 'Str',
    via { Wendy::Path -> new( addr => $_ ) };

use Data::Dumper;

sub BUILD
{
	# actual constructor

	my $self = shift;

	my $force_path = $self -> addr();

	my $t = ( $force_path or $ENV{ 'SCRIPT_NAME' } . $ENV{ 'PATH_INFO' } );

	$self -> addr( $t );
	$self -> path( &form_path( $t ) or 'root' );

}

sub form_path
{
	my $p = shift;

	return join( "_",  grep { $_ } split( /\W+/, $p ) );
}

__PACKAGE__ -> meta() -> make_immutable();

42;
