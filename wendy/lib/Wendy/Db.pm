use strict;

use Wendy::Config;

package Wendy::Db;

use Moose;


my $cached = undef;

has 'dbh' => ( is => 'rw', isa => 'DBI::db' );

use DBI;

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
	my ( $host, $db, $port, $user, $pass ) = @_;

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
		return $cached -> prepare( @_ );
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

sub selectrow_hashref
{
	my $self = shift;

	unless( ref( $self ) )
	{
		return $cached -> selectrow_hashref( @_ );
	}

	my $sql = shift;

	


	return $self -> dbh() -> selectrow_hashref( $sql );
}


# wheres moose ?

42;
