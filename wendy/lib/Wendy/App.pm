use strict;

package Wendy::App;

# Web application base class for Wendy.

use Moose;

has 'args' => ( is => 'rw', isa => 'HashRef' ); # CGI app args
has 'mode' => ( is => 'rw', isa => 'Str' ); # mode value holder
has 'ip' => ( is => 'rw', isa => 'Str' ); # user ip
has 'url' => ( is => 'rw', isa => 'URI', lazy => 1, builder => '_build_url' ); # current working url we're on
has 'scheme' => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_build_scheme' );

has 'core' => ( is => 'rw', isa => 'Wendy::Core' );

# shorter

sub _mode_arg      { 'mode' }
sub _run_modes     { [ 'default' ] } # run modes
sub _default_mode  { my $self = shift; my $t = $self -> _run_modes(); return $t -> [ 0 ]; } # it is convenient to assume that 1st mode is default 
sub _run_modes_map { { other_mode  => 'app_mode_default' } } # if needed to remap mode to another method

use Wendy::Util::List 'in';
use Carp::Assert;
use URI;

sub BUILD
{
	my $self = shift;

	$self -> __set_default_cgi_args();

	my @run_modes = @{ $self -> _run_modes() };

	my $mode = ( $self -> mode() or $self -> args() -> { $self -> _mode_arg() } );

	unless( &in( $mode, @run_modes ) )
	{
		$mode = $self -> _default_mode();
	}

	$self -> mode( $mode );

	if( $ENV{ 'REMOTE_ADDR' } eq '127.0.0.1' )
	{
		if( $ENV{ 'HTTP_NGINX_REAL_IP' } )
		{
			$ENV{ 'REMOTE_ADDR' } = $ENV{ 'HTTP_NGINX_REAL_IP' };
		}
	}

	$self -> ip( $ENV{ 'REMOTE_ADDR' } );
}

sub _build_url
{
	my $self = shift;

	my $rv = sprintf( '%s://%s%s', $self -> scheme(), $self -> core() -> host() -> name(), $ENV{ 'REQUEST_URI' } );

	my $u = URI -> new( $rv );

	return $u;
}

sub url_only_str
{
	my $self = shift;

	my $u = $self -> url();
	$u -> query_form( {} );

	return $u -> as_string();
}

sub _build_scheme
{
	my $self = shift;

	my $rv = 'http';

	if( $ENV{ 'HTTP_HTTPS' } or $ENV{ 'HTTPS' } )
	{
		$rv = 'https';
	}

	return $rv;
}

sub in_https
{
	my $self = shift;

	my $rv = 0;

	if( $self -> scheme() eq 'https' )
	{
		$rv = 1;
	}

	return $rv;
}

sub arg
{
	my ( $self, $key ) = @_;
	
	my $args = $self -> args();
	
	return $args -> { $key };
}

sub upload
{
	my ( $self, $file_field_name ) = @_;

	return $self -> core() -> cgi() -> upload( $file_field_name );
}

sub set_arg
{
	my $self = shift;

	my %args = @_;

	my %here_args = %{ $self -> args() };

	while( my ( $k, $v ) = each %args )
	{
		$here_args{ $k } = $v;
	}

	$self -> args( \%here_args );
}

sub run
{
	my $self = shift;

	unless( ref( $self ) )
	{
		# class name call, no prob, we'll create an object for you, pal
		return $self -> new() -> run();
	}

	if( my $t = $self -> init() )
	{

		if( ref( $t ) )
		{
			return $t;
		}

		return $self -> error( 'init', $t );
	}

	my $mode = $self -> mode();

	my $mode_method = 'app_mode_' . $mode;

	if( my $t = $self -> _run_modes_map() -> { $mode } )
	{
		# overrides
		$mode_method = $t;
	}

	if( my $t = $self -> always() )
	{

		if( ref( $t ) )
		{
			return $t;
		}


		return $self -> error( 'always', $t );
	}

	my $rv = $self -> $mode_method();

	$self -> cleanup();

	return $rv;
}

sub __set_default_cgi_args
{
	my $self = shift;

	my $cgi = $self -> core() -> cgi();

	my $t = $cgi -> vars();

	my $straight_args = {};

	foreach my $field ( keys %{ $t } )
	{
		my @all = $cgi -> param( $field );

		if( scalar @all == 1 )
		{
			$straight_args -> { $field } = $all[ 0 ];
		} else
		{
			$straight_args -> { $field } = \@all;
		}
	}

	$self -> args( $straight_args );
}

sub app_mode_default
{
	my $self = shift;

	return Wendy::Return -> new( data => 'Default app mode. Redefine app_mode_default method in your application.' );
}

sub always
{
	# something that should always be done, called after init
	# if returns error code, error() called
	my $self = shift;

	return 0;
}

sub init
{
	# app initialization, called first
	# if returns error code, error() called
	my $self = shift;

	return 0;
}

sub cleanup
{
	my $self = shift;
	return 0;
}

sub error
{
	my $self = shift;

	my ( $from, $code ) = @_;

	if( ref( $code ) eq 'Wendy::Return' ) # that is output returned, pass as is
	{
		return $code;
	}

	return Wendy::Return -> new( data => sprintf( '(Wendy::App) Application error default handler (%s, %s)', $from, $code ) );
}

42;
