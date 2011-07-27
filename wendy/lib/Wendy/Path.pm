use strict;

package Wendy::Path;

use Moose;

has 'path' => ( is => 'rw', isa => 'Str' );
has 'addr' => ( is => 'rw', isa => 'Str' );

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
	my $self = shift;
	
	my $p = shift;

	return join( "_",  grep { $_ } split( /\W+/, $p ) );
}

no Moose;

42;
