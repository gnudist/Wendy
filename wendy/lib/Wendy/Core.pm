use strict;

use Wendy::Path;
use Wendy::Config;
use Wendy::Db;
use Wendy::Host;
use Wendy::CGI;
use Wendy::Request;
use Wendy::Cookie;
use Wendy::Out;

use Apache2::Const;
use Digest::MD5 ();

package Wendy::Core;

use Moose;

has 'path'    => ( is => 'rw', isa => 'Wendy::Path'    );
has 'host'    => ( is => 'rw', isa => 'Wendy::Host'    );
has 'dbh'     => ( is => 'rw', isa => 'Wendy::Db'      );
has 'cgi'     => ( is => 'rw', isa => 'Wendy::CGI'     );
has 'req'     => ( is => 'rw', isa => 'Wendy::Request' );
has 'lng'     => ( is => 'rw', isa => 'Wendy::Lng'     );
has 'cookie'  => ( is => 'rw', isa => 'Wendy::Cookie'  );
has 'conf'    => ( is => 'rw', isa => 'Wendy::Config'  );
has 'mod_perl_req' => ( is => 'rw', isa => 'Apache2::RequestRec' );

sub mod_perl_return
{
	my $self = shift;

	my $rv = shift;

	my $req = $self -> req() -> mod_perl_req();

	$req -> status( $rv -> code() );
	$req -> status_line( join( ' ', ( $rv -> code(), $rv -> msg() ) ) );

	if( my $t = $rv -> ctype() )
	{
		my $ch = $rv -> charset();
		$req -> content_type( $t . ( $ch ? '; charset=' . $ch : '' ) );
	}

	if( my $t = $rv -> headers() )
	{
		foreach my $hdr ( @{ $t } )
		{
			$req -> headers_out() -> add( %{ $hdr } );
		}
	}

	unless( $req -> header_only() )
	{
		if( my $t = $rv -> file() )
		{
			$req -> sendfile( $t );
		}

		if( my $t = $rv -> data() )
		{
			$req -> print( $t );
		}
	}

	return Apache2::Const::OK;

}

sub BUILD
{
	# actual constructor

	my $self = shift;

	$self -> path( Wendy::Path -> new() );

	$self -> conf( Wendy::Config -> new() );
	$self -> dbh( Wendy::Db -> new() );

	$self -> host( Wendy::Host -> new() );

	$self -> cgi( Wendy::CGI -> new() );

	if( my $r = $self -> mod_perl_req() )
	{
		$self -> req( Wendy::Request -> new( mod_perl_req => $r ) );
	} else
	{
		die 'no other reqs support (yet!)';
	}

	# choose most appropriate language from host's languages

	$self -> cookie( Wendy::Cookie -> new() );
	$self -> language_init();

		

}


sub language_init
{
	my $self = shift;

	# 1. from query param ?lng=
	unless( $self -> lng() )
	{
		my $l = undef;

		if( ( $l = $self -> cgi() -> param( 'lng' ) )
		    and
		    ( my $lo = $self -> host() -> has_language( $l ) ) )
		{
			$self -> lng( $lo );
		}
	}
	
	# 2. from cookie lng
	unless( $self -> lng() )
	{
		my $c = undef;
		if( ( $c = $self -> cookie() -> value( 'lng' ) )
		    and
		    ( my $lo = $self -> host() -> has_language( $c ) ) )
		{
			$self -> lng( $lo );
		}
	}

	# 3. guessing from http-accept-language request header
	unless( $self -> lng() )
	{
KJXrK99GIPWBJpCe:
		foreach my $l ( $self -> http_accept_languages() )
		{
			if( my $lo = $self -> host() -> has_language( $l ) )
			{
				$self -> lng( $lo );
				last KJXrK99GIPWBJpCe;
			}
		}
	}

	unless( $self -> lng() )
	{
		$self -> lng( $self -> host() -> defaultlng() );
	}

	unless( $self -> lng() )
	{
		die 'completely impossibl';
	}

}

sub http_accept_languages
{
	# well, honestly i dont need self here

	my @rv = ();

	if( my $t = $ENV{ 'HTTP_ACCEPT_LANGUAGE' } )
	{
		my %h = ();

		$t =~ s/\s//g;
		foreach my $pair ( split( /,/, $t ) )
		{
			my ( $lng, $q ) = split( /;q=/, $pair );
			unless( $q )
			{
				$q = 1;
			}
			$h{ $lng } = $q;
		}

		@rv = sort { $h{ $b } <=> $h{ $a } } keys %h;

	}
	return @rv;

}


sub request_cache_id
{
	my $self = shift;

	my @t = ( $self -> path() -> path(),
		  $self -> lng() -> name(),
		  $self -> req() -> cache_id() );

	my $rv = join( ':', @t );

	return Digest::MD5::md5_hex( $rv );


}

sub cache_return
{
	my $self = shift;

	my $return_obj = shift;

	my $host = $self -> host();

	$host -> store_cache_return( $self -> request_cache_id(), $return_obj );

}

sub auto_output
{
	# TODO: discover and spawn output object

	my $self = shift;

	my $host = $self -> host();
	my $path = $self -> path();

	my $output = Wendy::Out -> new();


	if( $host -> has_path( $path ) )
	{
		if( my $o = $host -> has_cached( $self -> request_cache_id() ) )
		{

			$output -> cached( $o );


		} elsif( my $h = $host -> has_handler( $path ) )
		{
			$h -> core( $self );
			$output -> handler( $h );


		} elsif( my $t = $host -> has_template( $path ) )
		{
			$t -> lng( $self -> lng() );
			$output -> template( $t );

		} else
		{
			# well think of something more polite
			# later
			die sprintf( 'host %s has address %s but has no template or handler defined',
				     $host -> name(),
				     $path -> addr() );
		}



	} elsif( $host -> has_map( $path ) )
	{

		2;

	} else
	{
		# 404 err
		# TODO
		die 'nuff said';
		
	}

	return $output;

}


__PACKAGE__ -> meta() -> make_immutable();

42;
