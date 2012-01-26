use strict;

package Wendy::Handler;

use Moose;

has 'core' => ( is => 'rw', isa => 'Wendy::Core' );
has 'src' => ( is => 'rw', isa => 'Str' );

use Carp::Assert;

sub execute
{
	my $self = shift;

	assert( my $src = $self -> src(), 'this is an opensource or what?' );

	require $src;

	my $pkg = &Wendy::Path::form_path( $self -> core() -> host() -> name() ) .
	          '::' .
		  $self -> core() -> path() -> path();

	my $handler_object = $pkg -> new( core => $self -> core() );

	return $handler_object -> run();

}

__PACKAGE__ -> meta() -> make_immutable();

42;
