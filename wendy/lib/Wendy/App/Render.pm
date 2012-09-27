use strict;

package Wendy::App::Render;

use Moose;
extends 'Wendy::App';

has 'output' => ( is => 'rw', isa => 'Str', default => '' );
has 'output_macros' => ( is => 'rw', isa => 'Str', default => 'DYN_GENERIC_WORKS' );
has 'template' => ( is => 'rw', isa => 'Str' );

use Wendy::Shorts;
use Wendy::Templates::TT;

sub append_to_output
{
	my $self = shift;

	$self -> output( $self -> output() . join( '', @_ ) );
}

sub prepend_output_with
{
	
	my $self = shift;

	$self -> output( join( '', @_ ) . $self -> output() );
}

sub process_template
{
	my ( $self, $t ) = @_;

	return &tt( $t );
}

sub render_output
{
	my $self = shift;

	my %args = @_;

	my $template = ( $args{ 'Template' } or $self -> template() or $self -> wobj() -> { 'HPATH' } );

	my %rv = ();

	foreach my $f ( 'ctype', 'headers', 'code' )
	{
		if( my $t = $args{ $f } )
		{
			$rv{ $f } = $t;
		}
	}

	unless( exists $rv{ 'headers' } )
	{

		$rv{ 'headers' } = $self -> convert_headers_to_wendy_headers();
	}

	if( ( exists $args{ 'Nocache' } ) or ( my $ttl = $args{ 'TTL' } ) )
	{
		if( $args{ 'Nocache' } )
		{
			$rv{ 'nocache' } = 1;
		} else
		{
			$rv{ 'ttl' } = ( $ttl or 600 );
		}
	} else
	{
		$rv{ 'nocache' } = 1;
	}

	if( my $m = $self -> output_macros() )
	{
		&ar( $m => $self -> output() );
	}

	$rv{ 'data' } = $self -> process_template( $template );

	return \%rv;
}

no Moose;

42;
