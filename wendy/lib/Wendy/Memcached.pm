#!/usr/bin/perl

use strict;

package Wendy::Memcached;

require Exporter;

our @ISA         = qw( Exporter );

our @EXPORT      = qw( mc_init
		       mc_set
		       mc_get
		       mc_delete );
our @EXPORT_OK   = qw( mc_init
		       mc_set
		       mc_get
		       mc_delete );

our %EXPORT_TAGS = ( default => [ ] );
our $VERSION     = 1.00;

use Cache::Memcached;
use Wendy::Config ':memcached';

my $memd = undef;
my $mc_init = 0;

sub mc_init
{
	unless( $mc_init )
	{
		$mc_init = 1;
		$memd = new Cache::Memcached {
			'servers' => CONF_MC_SERVERS,
			'compress_threshold' => CONF_MC_THRHOLD,
			'no_rehash' => CONF_MC_NORHASH };

		if( defined $memd )
		{
			return 1;
		} else
		{
			return undef;
		}
	}
	return undef;
}

sub mc_set
{
	if( $mc_init )
	{
		return $memd -> set( @_ );
	}
	return undef;
}

sub mc_get
{
	if( $mc_init )
	{
		return $memd -> get( @_ );
	}
	return undef;
}

sub mc_delete
{
	if( $mc_init )
	{
		return $memd -> delete( @_ );
	}
	return undef;
}

1;
