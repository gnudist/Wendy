use strict;

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


use Wendy::Path;
use Wendy::Config;
use Wendy::Db;
use Wendy::Host;
use Wendy::CGI;
use Wendy::Request;
use Wendy::Cookie;

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
			my ( $lng, $q ) = split( /;/, $pair );
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

sub auto_output
{
	# TODO: discover and spawn output object

	my $self = shift;

	my $host = $self -> host();
	my $path = $self -> path();


	if( my $t = $host -> has_path( $path ) )
	{
		1;
	} elsif( $host -> has_map( $path ) )
	{
		2;
	}

	die 'also not implemented';

}


no Moose;

42;
