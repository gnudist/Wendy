use strict;

package Wendy::Return;

use Moose;

has 'code' => ( is => 'rw', isa => 'Int', default => 200 );
has 'ctype' => ( is => 'rw', isa => 'Str', default => 'text/html' );
has 'data' => ( is => 'rw', isa => 'Str' );
has 'file' => ( is => 'rw', isa => 'Str' );
has 'headers' => ( is => 'rw', isa => 'ArrayRef[HashRef]' );

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

42;
