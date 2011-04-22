#!/usr/bin/perl

use strict;

package Wendy::Hosts;

require Exporter;

use Wendy::Util;
use Wendy::Config;
use Wendy::Db;

our @ISA         = qw( Exporter );
our @EXPORT      = qw( http_host_init
		       form_address
		       get_host_languages
		       all_hosts );
our @EXPORT_OK   = qw( http_host_init
		       form_address
		       get_host_languages
		       get_host_aliases
		       get_aliases
		       is_alias
		       all_hosts );
our %EXPORT_TAGS = ( default => [ qw( ) ] );
our $VERSION     = 1.00;


sub get_host_aliases
{
	my $hid = shift;
	my @outcome = ();

	my $sql = sprintf( "SELECT alias FROM host_alias WHERE host=%s", &dbquote( $hid ) );
	my $sth = &dbprepare( $sql );
	$sth -> execute();
	while( my $data = $sth -> fetchrow_hashref() )
	{
		push @outcome, $data -> { "alias" };
	}
	$sth -> finish();
	return @outcome;
}

sub get_aliases
{
	my %args = @_;

	my $whereclause = '1=1';

	if( $args{ "Host" } )
	{
		my $host = $args{ "Host" };
		if( ref( $host ) )
		{
			$whereclause .= sprintf( " AND host IN ( %s )",
						 join( ', ', map { &dbquote( $_ ) } @$host ) );
		} else
		{
			$whereclause .= sprintf( " AND host=%s",
						 &dbquote( $host ) );
		}
	}

	my %outcome = &meta_get_records( Table => 'host_alias',
					 Where => $whereclause );

	return %outcome;
}

sub is_alias
{
	my $alias = shift;
	my $rv = undef;
	my $sth = &dbprepare( sprintf( "SELECT host FROM host_alias WHERE alias=%s",
				       &dbquote( $alias ) ) );
	$sth -> execute();

	if( $sth -> rows() == 1 )
	{
		my $data = $sth -> fetchrow_hashref();
		$rv = $data -> { "host" };
	}

	$sth -> finish();
	return $rv;
}

sub http_host_init
{
	my $host = shift;
	my %outcome = ();
	
	my $hostrec = &meta_get_record( Table => 'host',
					Where => sprintf( "host=%s", &dbquote( $host ) ),
					Memcache => CONF_MEMCACHED,
					Fields => [ 'id', 'host', 'defaultlng' ] );

	if( $hostrec )
	{
		%outcome = %$hostrec;

	} else
	{
		my $aliasrec = &meta_get_record( Table => 'host,host_alias',
						 Where => sprintf( "host.id=host_alias.host AND host_alias.alias=%s", &dbquote( $host ) ),
						 Memcache => CONF_MEMCACHED,
						 Fields => [ 'host.id AS id',
							     'host.host AS host',
							     'host.defaultlng AS defaultlng' ] );
		
		if( $aliasrec )
		{
			%outcome = %$aliasrec;
		} else
		{
			if( $host eq CONF_DEFHOST )
			{
				die 'host ' . CONF_DEFHOST . ' (CONF_DEFHOST) is not present in host table';
			} else
			{
				%outcome = &http_host_init( CONF_DEFHOST );
			}
		}
	}

	return %outcome;
}

sub form_address
{
	join( "_",  grep { $_ } split( /\W+/, shift ) );
}

sub get_host_languages
{
	my $hid = shift;
	my %outcome = ();

	my %recs = &meta_get_records( Table => 'language,hostlanguage',
				      Where => sprintf( "language.id=hostlanguage.lng AND hostlanguage.host=%s",
							&dbquote( $hid ) ),
				      Fields => [ 'language.lng AS lng',
						  'language.id AS id' ],
				      Memcache => CONF_MEMCACHED );
	
	foreach my $kid ( keys %recs )
	{
		$outcome{ $recs{ $kid } -> { "id" } } = $recs{ $kid } -> { "lng" };
	}

	return %outcome;
}

sub all_hosts
{
	my %outcome = ();

	my $sql = "SELECT id,host FROM host";
	my $sth = &dbprepare( $sql );
	$sth -> execute();

	while( my $data = $sth -> fetchrow_hashref() )
	{
		$outcome{ $data -> { "id" } } = \%{ { &http_host_init( $data -> { "host" } ) } };
	}

	$sth -> finish();

	return \%outcome;
}

1;
