#!/usr/bin/perl

use strict;

package Wendy::Modules;

require Exporter;

use Wendy::Db;
use Wendy::Util;


our @ISA         = qw( Exporter );
our @EXPORT      = qw( installed_modules
		       register_module
		       unregister_module
		       is_installed );
our @EXPORT_OK   = qw( installed_modules
		       register_module
		       unregister_module
		       is_installed );
our %EXPORT_TAGS = ( default => [ qw( ) ] );
our $VERSION     = 1.00;


sub installed_modules
{
	my %args = @_;

	my ( $host,
	     $id ) = @args{ "Host",
			    "Id" };


	return &meta_get_records( Table  => 'wemodule',
				  Fields => [ 'id', 'name', 'host' ],
				  Where => join( ' AND ',
						 ( $host ? sprintf( 'host=%s', &dbquote( $host ) ) : '1=1' ),
						 ( $id ? sprintf( 'id=%s', &dbquote( $id ) ) : '1=1' ) ) );
	
}


sub register_module
{
	my %args = @_;

	my ( $host,
	     $module ) = @args{ "Host",
				'Module' };


	my $sql = sprintf( "INSERT INTO wemodule (name,host) VALUES(%s,%s)",
			   &dbquote( $module ),
			   &dbquote( $host ) );
	
	unless( &wdbdo( $sql ) )
	{
		die &dbgeterror();
	}

	return 1;
}

sub is_installed
{
	my $modulename = shift;

	return &meta_get_records( Table => 'wemodule',
				  Where => sprintf( 'name=%s', &dbquote( $modulename ) ) );
	
}

sub unregister_module
{
	my %args = @_;

	my ( $host,
	     $module ) = @args{ "Host",
				'Module' };

	my $sql = sprintf( "DELETE FROM wemodule WHERE name=%s AND host=%s",
			   &dbquote( $module ),
			   &dbquote( $host ) );
	
	unless( &wdbdo( $sql ) )
	{
		die &dbgeterror();
	}

	return 1;
}

1;
