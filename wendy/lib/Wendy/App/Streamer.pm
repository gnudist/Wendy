use strict;
no warnings;

=pod



%DESCRIPTION:

Wendy::App extension allowing continuous app output while your app
is still running.

No cache.

Purpose - avoid output timeout on heavy and long running services .

28 Mar 2012

Test app:
---------

99.9% the same (see -/+ for diff)!

use strict;
no warnings;

use lib '/www/modules';

package Test;

use Moose;

- extends 'Wendy::App';
+ extends 'Wendy::App::Streamer';

sub app_mode_default
{
	my $self = shift;
	
	my $rv = { data => 'hi' };

- well, its usable if you didnt output anything yet
- but there is little point in :
-	return $rv;

+ instead we do:
+       return $self -> streamer_output( data => 'Hi!' );
+ or:
+       return $self -> streamer_output( $rv );
+ or:
+       return $self -> streamer_output();

}



Streaming app:
--------------

...

sub app_mode_default
{
	my $self = shift;
	
	while( my $data = &get_some_heavy_data_from_db() )
	{
		$self -> send_data( "processed data" );
	}

	return $self -> streamer_output();

}




Interface:
----------

* Send data immediately:

    $self -> send_data( "more data for you, pal" );


* Add header (no immediate set, will go when output):

    $self -> add_header( "Set-Cookie" => $coo -> as_string(),
			 "X-Something" => "here" );


* App output (use instead of plain returns):

    return $self -> streamer_output( wendyrv or hash or nothing at all );


The rest are rarely needed:


* Set content type:

    $self -> content_type( 'text/plain' );


* Set chartset:

    $self -> content_charset( 'UTF-8' );


* Set response code:

    $self -> response_code( 404 );


* Set response message:

    $self -> response_msg( "invalid request" );


* Print header (immediate set):

    $self -> print_header( "Set-Cookie" => $coo -> as_string(),
			   "X-Something" => "here" );



=cut

################################################################################
# You got your interface description, why do you keep looking?
# Do not look here further. It is not necessary. Really. I mean it.
################################################################################

package Wendy::App::Streamer;

use Moose;

extends 'Wendy::App';

has 'output_started' => ( is => 'rw', isa => 'Bool', default => 0 );

has 'content_type' => ( is => 'rw', isa => 'Str', default => 'text/html' );
has 'content_charset' => ( is => 'rw', isa => 'Str', default => 'UTF-8' );
has 'response_code' => ( is => 'rw', isa => 'Int', default => 200 );
has 'response_msg' => ( is => 'rw', isa => 'Str', default => 'dragon!' );

has 'r' => ( is => 'rw', isa => 'Apache2::RequestRec' );

use Carp::Assert;

sub BUILD
{
	my $self = shift;

	$self -> r( $self -> wobj() -> { 'REQREC' } );

}

sub _print_data
{
	my $self = shift;

	$self -> output_started( 1 );

	my $r = $self -> r();

	$r -> print( @_ );
	$r -> rflush();

}

sub _print_headers
{
	my $self = shift;

	my $r = $self -> r();

	my $code = $self -> response_code();

	$r -> status( $code );
	$r -> status_line( join( ' ', ( $code, $self -> response_msg() ) ) );

	my $charset = $self -> content_charset();

	$r -> content_type( $self -> content_type() . 
			    ( $charset ? '; charset=' . $charset : '' ) );

	foreach my $h ( @{ $self -> headers() } )
	{
		$self -> print_header( %{ $h } );
	}
}

sub print_header
{
	my $self = shift;

	my %header = @_;

	foreach my $k ( keys %header )
	{
		$self -> r() -> headers_out() -> add( $k => $header{ $k } );
	}
}

sub _send_file
{
	my ( $self, $file ) = @_;

	if( -f $file )
	{
		$self -> r() -> sendfile( $file );
	}
}


sub html_keep_alive
{
	# just sends spaces

	my $self = shift;

	$self -> send_data( "           " );

}

sub send_data
{
	my $self = shift;

	unless( $self -> output_started() )
	{
		$self -> _print_headers();
	}

	$self -> _print_data( @_ );

}

sub streamer_output
{
	my $self = shift;

	my @args = @_;
	my $rv = $args[ 0 ];

	if( $rv )
	{
		unless( ref( $rv ) )
		{
			# thats a candy for you, bugger
			my %rv = @args;
			$rv = \%rv;
		}

		if( $self -> output_started() )
		{
			# no headers, man, were online already!

			if( my $data = $rv -> { 'data' } )
			{
				$self -> _print_data( $data );
			}

			if( my $file = $rv -> { 'file' } )
			{
				$self -> _send_file( $file );
			}


		} else
		{

			$rv = $self -> _fill_rv_values( $rv );

			return $rv;
		}
	}

	return $self -> _wendy_rawmode();
}

sub _fill_rv_values
{
	my ( $self, $rv ) = @_;


	# if you want cache, say so clearly - add nocache => 0 to your rv
	unless( exists $rv -> { 'nocache' } )
	{
		$rv -> { 'nocache' } = 1;
	}

	my %h = ( msg => $self -> response_msg(),
		  code => $self -> response_code(),
		  ctype => $self -> content_type(),
		  charset => $self -> content_charset() );

	foreach my $k ( keys %h )
	{
		unless( exists $rv -> { $k } )
		{
			$rv -> { $k } = $h{ $k };
		}
	}

	if( my @headers = @{ $self -> headers() } )
	{
		my $h = ( $rv -> { 'headers' } or [] );

		my $whats_this = ref( $h );

		# wendy headers can be returned two ways:
		if( $whats_this eq 'ARRAY' )
		{
			foreach my $header ( @headers )
			{
				my ( $k, $v ) = each %{ $header };
				push @{ $h }, ( $k, $v );
			}

		} elsif( $whats_this eq 'HASH' )
		{
			foreach my $header ( @headers )
			{
				my ( $k, $v ) = each %{ $header };
				$h -> { $k } = $v;
			}

		} else
		{
			assert( 0, "dont know whats this: " . $whats_this );
		}

		$rv -> { 'headers' } = $h;
	}

	return $rv;
}

sub _wendy_rawmode
{
	my $self = shift;

	my $rv = { rawmode => 1 };

	return $rv;
}

no Moose;

42;
