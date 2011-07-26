use strict;

package Wendy::Core;

use Moose;

use Wendy::Config;

has 'path'    => ( is => 'rw', isa => 'Wendy::Path'    );
has 'host'    => ( is => 'rw', isa => 'Wendy::Host'    );
has 'dbh'     => ( is => 'rw', isa => 'Wendy::Db'      );
has 'cgi'     => ( is => 'rw', isa => 'Wendy::CGI'     );
has 'req'     => ( is => 'rw', isa => 'Wendy::Request' );
has 'lng'     => ( is => 'rw', isa => 'Wendy::Lng'     );
has 'cookie'  => ( is => 'rw', isa => 'Wendy::Cookie'  );
has 'conf'    => ( is => 'rw', isa => 'Wendy::Config'  );
has 'mod_perl_req' => ( is => 'rw', isa => 'Apache2::RequestRec' );

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

	unless( $self -> lng() )
	{
		if( ( my $l = $self -> cgi() -> param( 'lng' ) )
		    and
		    ( my $lo = $self -> host() -> has_language( $l ) ) )
		{
			$self -> lng( $lo );
		}
	}

	unless( $self -> lng() )
	{
		if( ( my $c = $self -> cookie() -> value( 'lng' ) )
		    and
		    ( my $lo = $self -> host() -> has_language( $c ) ) )
		{
			$self -> lng( $lo );
		}
	}

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


no Moose;

42;
