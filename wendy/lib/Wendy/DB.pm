use strict;

package Wendy::DB;

use Moose;

use Wendy::Config;

my $cached = undef;

has 'dbh' => ( is => 'rw', isa => 'DBI::db' );

sub BUILD
{
	# actual constructor

	my $self = shift;

	$self -> connect();
	$cached = $self;
}

sub connect
{
	my $self = shift;

	my $conf = Wendy::Config -> cached();

	{
		my $attempts_counter = 0;

TrfoRPoip2WEFPVG:
		while( 1 )
		{
			my $host = $conf -> random_db_host();

			if( $attempts_counter > 100 )
			{
				die 'could not connect to db';
			}
			$attempts_counter ++;

			if( my $d = &_do_connect( $host, 
						  $conf -> DBNAME(), 
						  $conf -> DBPORT(),
						  $conf -> DBUSER(),
						  $conf -> DBPASSWORD() ) )
			{
				$self -> dbh( $d );
				last TrfoRPoip2WEFPVG;
			}
			sleep( 1 );
		}
	}


}

sub cached
{
	return $cached;
}

sub _do_connect
{
	my ( $host, $db, $port, $user, $pass );

	my $dbh = DBI -> connect( 'dbi:Pg:dbname=' . $db . ';host=' . $host . ';port=' . $port,
			          $user,
				  $pass,
				  {
					  RaiseError => 0,
					  AutoCommit => 1
				  } );
	return $dbh;
}

sub prepare
{
	my $self = shift;

	unless( ref( $self ) )
	{
		return $cached -> dbprepare( @_ );
	}

	my $sql = shift;

	my $sth = undef;

	unless( $sth = $self -> dbh() -> prepare( $sql ) )
	{
		die $self -> errstr();
	}

	return $sth;

}

sub errstr
{
	my $self = shift;

	unless( ref( $self ) )
	{
		return $cached -> errstr();
	}
	return $self -> dbh() -> errstr();

}

sub quote
{
	my $self = shift;

	unless( ref( $self ) )
	{
		return $cached -> quote( @_ );
	}
	return $self -> dbh() -> quote( @_ );

}

sub selectrow
{
	my $self = shift;

	unless( ref( $self ) )
	{
		return $cached -> selectrow( @_ );
	}

	my $sql = shift;

	return $self -> dbh() -> selectrow_hashref( $sql );
}

no Moose;

42;
