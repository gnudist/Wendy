#!/usr/bin/perl

use strict;

package Wendy::Users;

require Exporter;

use Wendy::Config;
use Wendy::Db;

use File::Spec;

our @ISA         = qw( Exporter );
our @EXPORT      = qw( get_user );
our @EXPORT_OK   = qw( get_user );
our %EXPORT_TAGS = ( default => [ qw( ) ] );
our $VERSION     = 1.00;

sub get_user
{
	my %args = @_;

	my ( $username,
	     $userid,
	     $userpassword ) = @args{ "Login",
				      "Id",
				      "Password" };

	my %user = ();

	my $sql = "SELECT id,login,password,host,flag FROM weuser WHERE 1=1 ";

	if( $userid )
	{
		$sql .= " AND id=" . &dbquote( $userid );
	}

	if( $username )
	{
		$sql .= " AND login=" . &dbquote( $username );
	}

	if( $userpassword )
	{
		$sql .= " AND password=" . &dbquote( $userpassword );
	}
	my $sth = &dbprepare( $sql );
	$sth -> execute();

	if( $sth -> rows() == 1 )
	{
		my $data = $sth -> fetchrow_hashref();
		%user = %$data;

	} elsif( $sth -> rows() > 1 )
	{
		while( my $data = $sth -> fetchrow_hashref() )
		{
			$user{ $data -> { "id" } } = $data;
		}

	} elsif( $sth -> rows() != 0 )
	{
		die 'Bad rows count: ' . $sth -> rows();
	}

	$sth -> finish();

	return \%user;
}

1;
