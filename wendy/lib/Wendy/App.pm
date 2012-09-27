use strict;

use Wendy::Compat::Lng;

package Wendy::App;

# Web application base class for Wendy.

use Moose;

has 'args' => ( is => 'rw', isa => 'HashRef' ); # CGI app args
has 'mode' => ( is => 'rw', isa => 'Str' ); # mode value holder
has 'wobj' => ( is => 'rw', isa => 'HashRef' );

has 'ip' => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_build_ip' ); # user ip
has 'url' => ( is => 'rw', isa => 'URI', lazy => 1, builder => '_build_url' ); # current working url we're on
has 'scheme' => ( is => 'rw', isa => 'Str', lazy => 1, builder => '_build_scheme' );

has 'headers' => ( is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { [] } );
has 'out_cookies' => ( is => 'rw', isa => 'ArrayRef[CGI::Cookie]', default => sub { [] } );

# shorter

sub _mode_arg      { 'mode' }
sub _run_modes     { [ 'default' ] } # run modes
sub _default_mode  { my $self = shift; my $t = $self -> _run_modes(); return $t -> [ 0 ]; } # it is convenient to assume that 1st mode is default 
sub _run_modes_map { { other_mode  => 'app_mode_default' } } # if needed to remap mode to another method

use Wendy::Util  'in';
use Carp::Assert 'assert';
use CGI         ();
use CGI::Cookie ();
use TryCatch;

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

	unless( $self -> wobj() )
	{
		$self -> wobj( \%Wendy::WOBJ );
	}
}

sub set_cookie
{
	my $self = shift;

	my %args = @_;

	{
		# defaults:

		$args{ '-domain' } ||= $self -> wobj() -> { 'HOST' } -> { 'host' };
		$args{ '-expires' } ||= '+1d';

	}

	my $cookie = CGI::Cookie -> new( %args );

	push @{ $self -> out_cookies() }, $cookie;
}

sub get_cookie
{
	my ( $self, $coo_name ) = @_;

	my $w = $self -> wobj();
	my $rv = undef;

	if( ref( $w -> { 'COOKIES' } )
	    and
	    ref( $w -> { 'COOKIES' } -> { $coo_name } ) )
	{
		$rv = $w -> { 'COOKIES' } -> { $coo_name } -> value();
	}
	return $rv;
}

sub _build_ip
{
	my $self = shift;

	if( $ENV{ 'REMOTE_ADDR' } eq '127.0.0.1' )
	{
		if( $ENV{ 'HTTP_NGINX_REAL_IP' } )
		{
			$ENV{ 'REMOTE_ADDR' } = $ENV{ 'HTTP_NGINX_REAL_IP' };
		}
	}

	return ( $ENV{ 'REMOTE_ADDR' } or '127.0.0.1' );
}

sub _build_url
{
	my $self = shift;
	my $rv = sprintf( '%s://%s%s', $self -> scheme(), $ENV{ 'HTTP_HOST' }, $ENV{ 'REQUEST_URI' } );
	my $u = URI -> new( $rv );

	return $u;
}




# get request header value
sub header_in
{
	my ( $self, $header ) = @_;

	return $self -> wobj() -> { "REQREC" } -> headers_in() -> { $header };
}

# You can register output headers from any part of your application now:
# $self -> add_header( XCoolHeader => 123 );

sub add_header
{
	my $self = shift;

	my @headers = @_;

	my @now_headers = @{ $self -> headers() };


	while( my $field = shift @headers )
	{
		my $value = shift @headers;

		my $t = { $field => $value };

		push @now_headers, $t;

	}

	$self -> headers( \@now_headers );
}

sub convert_headers_to_wendy_headers
{
	my $self = shift;

	my @myheaders = @{ $self -> headers() };

	my @rvheaders = ();

	if( @myheaders )
	{
		foreach my $t ( @myheaders )
		{
			push @rvheaders, %{ $t };
		}
	}

	foreach my $coo ( @{ $self -> out_cookies() } )
	{
		my %t = ( 'Set-Cookie' => $coo -> as_string() );
		push @rvheaders, %t;
	}

	return ( scalar @rvheaders ? \@rvheaders : undef );
}

sub remove_header_by_name
{
	my $self = shift;

	my %names_to_remove = map { $_ => 1 } @_;

	my @new_headers = ();

	foreach my $header ( @{ $self -> headers() } )
	{
		my $hname = ${ [ keys %{ $header } ] }[ 0 ];

		unless( exists $names_to_remove{ $hname } )
		{
			push @new_headers, $header;
		}
	}

	$self -> headers( \@new_headers );
}

sub remove_cookie_by_name
{
	my $self = shift;

	my @names_to_remove = @_;
	my @new_cookies = ();

	foreach my $coo ( @{ $self -> out_cookies() } )
	{
		
		unless( &in( $coo -> name(), @names_to_remove ) )
		{
			push @new_cookies, $coo;
		}
	}

	$self -> out_cookies( \@new_cookies );
}


sub lng
{
	my ( $self, $which_lng ) = @_;

	my $w = $self -> wobj();

	my $l = ( $which_lng or $w -> { 'LNG' } );

	assert( my $id = $w -> { 'RLNGS' } -> { $l } );

	my $lng = Wendy::Compat::Lng -> new( id => $id,
					     name => $l );

	return $lng;
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

	return scalar $self -> wobj() -> { 'CGI' } -> upload( $file_field_name );
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
		return $self -> new( @_ ) -> run();
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

	my $rv = undef;


	try
	{
		$rv = $self -> $mode_method();

	} catch ( EjectException $e )
	{
		$rv = $e -> rv();
	};

	$self -> cleanup();

	return $rv;
}

sub eject
{
	my ( $self, $rv ) = @_;

	unless( ref( $rv ) )
	{
		$rv = $self -> nctd( $rv );
	}

	die EjectException -> new( rv => $rv );
}

sub __set_default_cgi_args
{
	my $self = shift;

	my $cgi = $Wendy::WOBJ{ 'CGI' };

	unless( $cgi )
	{
		# in case we work offline
		$cgi = CGI -> new();
	}

	my $t = $cgi -> Vars();

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

	return $self -> ncd( 'Default app mode. Redefine this method in your application.' );
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

	if( ref( $code ) ) # that is output returned, pass as is
	{
		return $code;
	} 

	return $self -> nctd( sprintf( '(Wendy::App) Application error default handler (%s, %s)', $from, $code ) );
}


sub set_redirect_location
{
	my ( $self, $url ) = @_;

	my $l = 'Location';

	$self -> remove_header_by_name( $l );
	$self -> add_header( $l => $url );

}

# Not Cached ReDirect
sub ncrd
{
	my ( $self, $url, $code ) = @_;

	$self -> set_redirect_location( $url );

	return { nocache => 1,
		 code => ( $code or 302 ),
		 headers => $self -> convert_headers_to_wendy_headers() };

}

# Cached ReDirect
sub crd
{
	my ( $self, $url, $ttl, $code ) = @_;

	$self -> set_redirect_location( $url );

	return { ttl => ( $ttl or 600 ),
		 code => ( $code or 302 ),
		 headers => $self -> convert_headers_to_wendy_headers() };

}

# Not Cached Data 
sub ncd
{
	my ( $self, $data, $ctype, $code ) = @_;

	return { nocache => 1,
		 ctype => $ctype,
		 headers => $self -> convert_headers_to_wendy_headers(),
		 code => $code,
		 data => $data };
}


# Cached Data 
sub cd
{
	my ( $self, $data, $ttl, $ctype ) = @_;

	return { ttl => ( $ttl or 3600 ),
		 headers => $self -> convert_headers_to_wendy_headers(),
		 ctype => $ctype,
		 data => $data };
}


# Not Cached Text Data
sub nctd
{
	my ( $self, $data ) = @_;


	return $self -> ncd( $data, 'text/plain' );

 # { nocache => 1,
 # 		 ctype => 'text/plain',
 # 		 data => $data };

}

package EjectException;

use Moose;

has 'rv' => ( is => 'rw', isa => 'HashRef' );

42;
