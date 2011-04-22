#!/usr/bin/perl

use strict;

package Wendy::Procs;

require Exporter;

use Wendy::Config;
use Wendy::Db;



our @ISA         = qw( Exporter );
our @EXPORT      = qw( get_all_proc_names
		       get_proc );
our @EXPORT_OK   = qw( get_all_proc_names
		       get_proc );
our %EXPORT_TAGS = ( default => [ qw( ) ] );
our $VERSION     = 1.00;

sub get_all_proc_names
{
	my %args = @_;

	my %procs = ();

	my $sql = "SELECT id,name,body FROM perlproc WHERE 1=1";
	my $sth = &dbprepare( $sql );
	$sth -> execute();

	while( my $data = $sth -> fetchrow_hashref() )
	{
		$procs{ $data -> { "id" } } = $data;
	}

	$sth -> finish();

	return \%procs;
}

sub get_proc
{
	my %args = @_;

	my ( $id,
	     $name ) = @args{ "Id",
			      "Name" };

	my %procs = ();

	my $sql = "SELECT id,name,body FROM perlproc WHERE 1=1 ";

	if( $id )
	{
		$sql .= " AND id=" . &dbquote( $id );
	}
	
	if( $name )
	{
		$sql .= " AND name=" . &dbquote( $name );
	}

	my $sth = &dbprepare( $sql );
	$sth -> execute();

	while( my $data = $sth -> fetchrow_hashref() )
	{
		$procs{ $data -> { "id" } } = $data;
	}

	$sth -> finish();

	return \%procs;
}

1;
