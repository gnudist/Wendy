#!/usr/bin/perl

use strict;

package Wendy::Templates::TT;

require Exporter;

use Wendy;
use Wendy::Config;
use Wendy::Templates;

use File::Spec;
use Template;

our @ISA         = qw( Exporter );
our @EXPORT      = qw( tt tt_data );
our @EXPORT_OK   = @EXPORT;
our $VERSION     = 1.00;

sub tt
{
	my $tplname = shift;

	my $w = \%Wendy::WOBJ;

	unless( $tplname )
	{
		$tplname = $w -> { 'HPATH' };
	}

	my $allhostspath = File::Spec -> catdir( CONF_VARPATH, 'hosts' );
	my $path = File::Spec -> catdir( $allhostspath, $w -> { 'HOST' } -> { 'host' }, 'tpl' );
	
	my $config = { INCLUDE_PATH => [ $path,
					 $allhostspath ],
		       POST_CHOMP   => 1,
		       EVAL_PERL    => 1 };

	my $template = Template -> new( $config );

	my $output = '';

	unless( $template -> process( $tplname, \%Wendy::Templates::REPLACES, \$output ) )
	{
		$output = $template -> error();
	}

	return $output;
}

sub tt_data
{
	my $data = shift;
	return &tt( \$data );
}

1;
