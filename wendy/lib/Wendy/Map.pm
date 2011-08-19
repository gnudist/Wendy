
use Wendy::Util::File;
use Wendy::Path;

package Wendy::Map;

use Moose;

has 'file' => ( is => 'ro', required => 1, isa => 'Str' );
has 'map' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

use Data::Dumper;

sub BUILD
{
	my $self = shift;

	my $f = $self -> file();

	my $map = $self -> map();

	if( -f $f )
	{
		my $data = &Wendy::Util::File::slurp( $f );
		
		foreach my $line ( split( /[\x0d\x0a]+/, $data ) )
		{
			my ( $k, $v ) = &parse_map_line( $line );
			
			if( $k and $v )
			{
				$map -> { $k } = $v;
			}

		}
		$self -> map( $map );


	}
}

sub match
{
	my $self = shift;

	my $what = shift;
	my $mask = $what;

	if( ref( $what ) )
	{
		$mask = $what -> addr();
	}

	my %map = %{ $self -> map() };
	my $addr = undef;

	if( my $t = $map{ $mask } )
	{
		$addr = $t;

	} else
	{
AouzGIByOgWMpxeW:
		foreach my $regexp ( keys %map )
		{
			if( $mask =~ /$regexp/ )
			{
				$addr = $map{ $regexp };
				last AouzGIByOgWMpxeW;
			}
		}
	}

	my $rv = undef;

	if( $addr )
	{
		$rv = Wendy::Path -> new( addr => $addr );
	}

	return $rv;

}

sub parse_map_line
{
	my $l = shift;

	$l =~ s/\s+//g;

	my ( $k, $v ) = ( '', '' );

	if( $l =~ /^\((.+)\)(.+)$/ )
	{
		( $k, $v ) = ( $1, $2 );
	}

	return ( $k, $v );

}

42;
