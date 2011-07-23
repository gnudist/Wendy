use strict;

package Wendy::Path;

use Moose;

has 'path' => ( is => 'rw', isa => 'Str' );
has 'addr' => ( is => 'rw', isa => 'Str' );

sub BUILD
{
	# actual constructor

	my $self = shift;

	my $force_path = shift;

	my $t = ( $force_path or $ENV{ 'SCRIPT_NAME' } . $ENV{ 'PATH_INFO' } );

	$self -> addr( $t );
	$self -> path( &path( $t ) or 'root' );

}

sub path
{
	join( "_",  grep { $_ } split( /\W+/, shift ) );
}

no Moose;

42;
