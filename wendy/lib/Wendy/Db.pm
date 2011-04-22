#!/usr/bin/perl

use strict;

package Wendy::Db;

require Exporter;

our @ISA         = qw( Exporter );

our @EXPORT      = qw( dbconnect
		       wdbconnect
		       wdbbegin
		       wdbcommit
		       wdbrollback
		       dbprepare
		       wdbprepare
		       dbdisconnect
		       wdbdisconnect
		       dbquote
		       dbgeterror
		       wdbgeterror
		       wdbdo
		       dbselectrow
		       seqnext
		       wseqnext
		       wtransaction );

our @EXPORT_OK   = qw( dbconnect
		       wdbconnect
		       __do_connect
		       wdbbegin
		       wdbcommit
		       wdbrollback
		       dbprepare
		       wdbprepare
		       dbdisconnect
		       wdbdisconnect
		       dbquote
		       wdbquote
		       dbgeterror
		       wdbgeterror
		       dbdo
		       wdbdo
		       dbselectrow
		       seqnext
		       wseqnext
		       wtransaction );

our %EXPORT_TAGS = ( default => [ ] );
our $VERSION     = 1.00;

use Wendy::Config ':dbauth';
use DBI;
use DBD::Pg;

my $rdbh = undef;
my $wdbh = undef;

my $one_dbh = 0;

sub dbconnect
{
	unless( $rdbh )
	{
		my $rdbhost = CONF_DBHOST;

		if( ref $rdbhost )
		{
rDhHOm41w4tWnBxp:
			while( 1 ) # die if attempts count more than x ?
			{
				my $host = &__rand_el( @$rdbhost );

				if( $rdbh = &__do_connect( $host ) )
				{
					last rDhHOm41w4tWnBxp;
				}
			}
		} else
		{
			$rdbh = &__do_connect( $rdbhost );
		}
	}

	return $rdbh;
}


sub wdbconnect
{
	unless( $wdbh )
	{
		my $wdbhost = CONF_WDBHOST;

		if( $wdbhost )
		{
			if( ref $wdbhost )
			{

gQUZ58SVNa3exkcY:
				while( 1 )
				{
					my $host = &__rand_el( @$wdbhost );
					if( $wdbh = &__do_connect( $host ) )
					{
						last gQUZ58SVNa3exkcY;
					}
				}
			} else
			{
				$wdbh = &__do_connect( $wdbhost );
			}
		} else
		{
			$one_dbh = 1;
			$wdbh = $rdbh;
		}
	}

	return $wdbh;
}

sub __do_connect
{
	my $host = shift;

	my $dbh = DBI -> connect( 'dbi:Pg:dbname=' . CONF_DBNAME . ';host=' . $host . ';port=' . CONF_DBPORT,
			          CONF_DBUSER,
				  CONF_DBPASSWORD,
				  {
					  RaiseError => 0,
					  AutoCommit => 1
				  } );
	return $dbh;
}

sub wdbbegin
{
	$wdbh -> begin_work() or return undef;
	return 1;
}

sub wdbcommit
{
	$wdbh -> commit() or return undef;
	return 1;
}

sub wdbrollback
{
	$wdbh -> rollback() or return undef;
	return 1;
}

sub dbprepare
{
	my $sql = shift;
	my $sth = $rdbh -> prepare( $sql ) or return undef;

	return $sth;
}

sub wdbprepare
{
	my $sql = shift;
	my $sth = $wdbh -> prepare( $sql ) or return undef;

	return $sth;
}

sub dbselectrow
{
	return $rdbh -> selectrow_hashref( shift );
}

sub dbdo
{
	my $sql = shift;
	return $rdbh -> do( $sql );
}

sub wdbdo
{
	my $sql = shift;
	return $wdbh -> do( $sql );
}

sub dbgeterror
{
	return $rdbh -> errstr();
}

sub wdbgeterror
{
	return $wdbh -> errstr();
}

sub dbquote
{
	my $val = shift;
	return $rdbh -> quote( $val );
}

sub wdbquote
{
	my $val = shift;
	return $wdbh -> quote( $val );
}

sub dbdisconnect
{
	$rdbh -> disconnect();
	$rdbh = undef;

	if( $one_dbh )
	{
		$wdbh = undef;
	}
}

sub wdbdisconnect
{
	unless( $one_dbh )
	{
		if( $wdbh )
		{
			$wdbh -> disconnect();
			$wdbh = undef;
		}
	}
}

sub seqnext
{
	my $sname = shift;

	my $sql = sprintf( "SELECT nextval(%s) AS id", &dbquote( $sname ) );
	my $sth = &wdbprepare( $sql );
	$sth -> execute();
	my $data = $sth -> fetchrow_hashref();
	my $rv = $data -> { "id" };
	$sth -> finish();

	return int( $rv );
}

sub wseqnext
{
	my $sname = shift;
	return &seqnext( $sname );
}

sub wtransaction
{
	my $error = 0;
	my $failed_req = undef;
	my $errmsg = undef;

	&wdbconnect();

	unless( $error )
	{
		unless( &wdbbegin() )
		{
			$error = 1;
			$failed_req = 'BEGIN';
			$errmsg = &wdbgeterror();
		}
	}

	unless( $error )
	{
xFPy1bMQuwLVioXa:
		foreach my $req ( @_ )
		{
			unless( &wdbdo( $req ) )
			{
				$error = 1;
				$failed_req = $req;
				$errmsg = &wdbgeterror();
				last xFPy1bMQuwLVioXa;
			}
		}
	}

	if( $error )
	{
		&wdbrollback();
	} else
	{
		unless( &wdbcommit() )
		{
			$error = 1;
			$failed_req = 'COMMIT';
			$errmsg = &wdbgeterror();
		}
	}

	return { error => $error,
		 req   => $failed_req,
		 msg   => $errmsg };
}

sub __rand_el # returns random array element
{
	return $_[ int( rand( $#_ + 1 ) ) ];
}

1;
