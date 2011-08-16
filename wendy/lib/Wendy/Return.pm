use strict;

package Wendy::Return;

use Moose;

has 'code' => ( is => 'rw', isa => 'Int', default => 200 );
has 'ctype' => ( is => 'rw', isa => 'Str', default => 'text/html' );
has 'data' => ( is => 'rw', isa => 'Str' );
has 'charset' => ( is => 'rw', isa => 'Str', default => 'UTF-8' );
has 'msg' => ( is => 'rw', isa => 'Str', default => 'okay' );
has 'file' => ( is => 'rw', isa => 'Str' );
has 'headers' => ( is => 'rw', isa => 'ArrayRef[HashRef]' );
has 'ttl' => ( is => 'rw', isa => 'Int', default => 600 );
has 'expires' => ( is => 'rw', isa => 'Int' );
has 'cache' => ( is => 'rw', isa => 'Bool', default => 0 );

sub add_header
{

	my $self = shift;

	my @h = @{ $self -> headers() };

	my %headers = @_;

	while( my ( $k, $v ) = each %headers )
	{
		push @h, { $k => $v };
	}

	$self -> headers( \@h );

}

sub remove_header
{

	my $self = shift;

	my $name = shift;

	# well optimize that
	# later
	# if you want

	my @h = @{ $self -> headers() };
	my @newh = ();

	foreach my $h ( @h )
	{
		unless( exists $h -> { $name } )
		{
			push @newh, $h
		}
	}

	$self -> headers( \@newh );



}

sub expired
{
	my $self = shift;

	my $rv = 0;

	if( my $t = $self -> expires() )
	{
		if( $t < time() )
		{
			$rv = 1;
		}
		
	}

	return $rv;
}

__PACKAGE__ -> meta() -> make_immutable();

42;
