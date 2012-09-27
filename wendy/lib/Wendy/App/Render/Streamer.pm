use strict;

=pod


%DESCRIPTION:

Wendy::App::Render extension allowing continuous app output while your app
is still running.

Find Wendy::App::Streamer description. Somewhere. Now.


Addition to Wendy::App::Streamer interface:
----------------------------------------------


* Send string of spaces to client, harmless for html output, but this
  will prevent output timeout. Put this to your init() or always() if
  your heavy app is HTML-only:

    $self -> html_keep_alive();

  (can be called in loops)


=cut

package Wendy::App::Render::Streamer;

use Moose;

extends 'Wendy::App::Streamer';

has 'output' => ( is => 'rw', isa => 'Str', default => '' );
has 'output_macros' => ( is => 'rw', isa => 'Str', default => 'DYN_GENERIC_WORKS' );
has 'template' => ( is => 'rw', isa => 'Str' );

use Wendy::Shorts;
use Wendy::Templates::TT;
use Carp::Assert;

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

	my $rv = $self -> _original_render_output_which_is_now_internal_method( @_ );

	return $self -> streamer_output( $rv );

}

sub _original_render_output_which_is_now_internal_method
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
