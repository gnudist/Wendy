use strict;

package Wendy::Core;

use Moose;

use Wendy::Config;

has 'path'    => ( is => 'rw', isa => 'Wendy::Path'    );
has 'host'    => ( is => 'rw', isa => 'Wendy::Host'    );
has 'dbh'     => ( is => 'rw', isa => 'Wendy::DB'      );
has 'cgi'     => ( is => 'rw', isa => 'Wendy::CGI'     );
has 'req'     => ( is => 'rw', isa => 'Wendy::Request' );
has 'lng'     => ( is => 'rw', isa => 'Wendy::Lng'     );
has 'cookies' => ( is => 'rw', isa => 'Wendy::Cookie'  );
has 'conf'    => ( is => 'rw', isa => 'Wendy::Config'  );

sub BUILD
{
	# actual constructor

	my $self = shift;

	$self -> path( Wendy::Path -> new() );
	$self -> conf( Wendy::Config -> new() );
	$self -> dbh( Wendy::Db -> new() );
	$self -> host( Wendy::Host -> new() );



}



no Moose;

42;
