use strict;

use Wendy::Template;
use Wendy::Util::Db;
use Wendy::Config;
use Wendy::Lng;

use File::Spec;

package Wendy::Host;

use Moose;

has 'id' => ( is => 'rw', isa => 'Int' );
has 'name' => ( is => 'rw', isa => 'Str' );
has 'defaultlng' => ( is => 'rw', isa => 'Wendy::Lng' );
has 'languages' => ( is => 'rw', isa => 'ArrayRef[Wendy::Lng]' );
has 'aliases' => ( is => 'rw', isa => 'ArrayRef[Str]' );

sub BUILD
{
	my $self = shift;

	my $force_host_name = $self -> name();
	
	unless( $self -> init( $force_host_name or lc( $ENV{ 'HTTP_HOST' } ) ) )
	{
		$self -> init( Wendy::Config -> cached() -> DEFHOST() ) or die 'host initialization failed';
	}


}

sub init
{
	my $self = shift;

	my $name = shift;

	if( my $host_rec = Wendy::Util::Db -> query( Table => 'wendy_host',
						     Where => sprintf( 'host=%s', 
								       Wendy::Db -> quote( $name ) ) ) )
	{

		$self -> id( $host_rec -> { 'id' } );
		$self -> name( $host_rec -> { 'host' } );


		{
		
			my %l = Wendy::Util::Db -> query_many( Table => 'wendy_host_language hl',
							       Fields => [ 'hl.lng AS id' ],
							       Where => sprintf( 'hl.host=%d', $self -> id() ) );
			
			unless( %l )
			{
				die sprintf( 'no languages defined for host %s', $self -> name() );
			}
			my @l = ();
			
			foreach my $l ( keys %l )
			{
				my $lng = Wendy::Lng -> new( id => $l );
				push @l, $lng;
			}
			
			$self -> languages( \@l );
		}

		$self -> defaultlng( Wendy::Lng -> new( id => $host_rec -> { 'defaultlng' } ) );

	
	} else
	{
		if( my $alias_rec = Wendy::Util::Db -> query( Table => 'wendy_host_alias a,wendy_host h',
							      Fields => [ 'h.host as name' ],
							      Where => sprintf( 'a.alias=%s AND h.id=a.host',
										Wendy::Db -> quote( $name ) ) ) )
		{
			return $self -> init( $alias_rec -> { 'name' } );
		}
	}

	return 1;

}

sub has_language
{
	my $self = shift;

	my $language_name = shift;

	my $rv = undef;

uOvotgH7xPKKSgRt:
	foreach my $l ( @{ $self -> languages() } )
	{
		if( $l -> name() eq $language_name )
		{
			$rv = $l;
			last uOvotgH7xPKKSgRt;
		}
	}
	return $rv;
}

sub has_path
{
	my $self = shift;

	my $path = shift;

	my $conf = Wendy::Config -> cached();

	# we check path, we find script or template (in this order)

	my $requested = File::Spec -> canonpath( File::Spec -> catfile( $conf -> VARPATH(),
									'hosts',
									$self -> name(),
									'htdocs',
									$path -> addr() ) );

	my $rv = 0;

	if( -d $requested )
	{
		$rv = 1;
	}

	return $rv;


}

sub has_template
{
	my $self = shift;
	my $path = shift;

	my $conf = Wendy::Config -> cached();

	my $requested = File::Spec -> canonpath( File::Spec -> catfile( $conf -> VARPATH(),
									'hosts',
									$self -> name(),
									'tpl',
									$path -> path() ) );

	my $rv = undef;

	if( -f $requested )
	{
		$rv = Wendy::Template -> new( host => $self,
					      path => $path );
	}
	
	return $rv;

}



42;
