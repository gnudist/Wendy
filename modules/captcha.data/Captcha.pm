#!/usr/bin/perl

use strict;

package Wendy::Modules::Captcha;
require Exporter;

use GD::SecurityImage;
use File::Spec;
use File::Util 'escape_filename';
use Wendy::Config 'CONF_VARPATH';
use Wendy::Util 'rand_array';
use Digest::MD5 'md5_hex';
use URI;

use Fcntl ':flock';
our @ISA         = qw( Exporter );
our @EXPORT      = qw( check_captcha );
our @EXPORT_OK   = qw( check_captcha );

our $VERSION     = 1.00;

sub new
{
	my $invocant = shift;
	my $class = ( ref( $invocant ) or $invocant );

	my %args = @_;

	my %defaults = ( 'scramble' => 1,
			 'width'    => 300,
			 'height'   => 80,
			 'lines'    => 10,
			 'font'     => File::Spec -> catfile( CONF_VARPATH,
							      'modules',
							      'captcha.data',
							      'arial.ttf' ) );

	foreach my $key ( keys %defaults )
	{
		unless( defined( $args{ $key } ) )
		{
			$args{ $key } = $defaults{ $key };
		}
	}

	my $self = {};
	my $image = GD::SecurityImage -> new( %args );

	if( $image )
	{
		$self -> { 'IMAGE' } = $image;
	}
	$self -> { 'PASS' } = md5_hex( rand() );

	bless( $self, $class );
	return $self;
}

sub set_text
{
	my $self = shift;
	my $text = shift;

	$self -> { 'TEXT' } = 1;
	$self -> { 'IMAGE' } -> random( $text );
	return 1;
}

sub get_public
{
	my $self = shift;
	my $public = "";

	unless( $self -> { 'TEXT' } )
	{
		$self -> set_text( undef );
	}
	my $text = $self -> get_text();

	$public = $self -> get_pass() .
	          '_' .
		  md5_hex( $text . $self -> get_pass() );

	return $public;
}

sub get_pass
{
	my $self = shift;
	return $self -> { 'PASS' };
}

sub get_text
{
	my $self = shift;

	return $self -> { 'IMAGE' } -> random_str();
}

sub my_create
{
	my $self = shift;

	unless( $self -> { 'CREATED' } )
	{
		$self -> { 'CREATED' } = 1;
		$self -> { 'IMAGE' } -> create( ttf => &rand_array( 'circle',
								    'default',
								    'ellipse',
								    'ec',
								    'rect'  ) );
		$self -> { 'IMAGE' } -> particle();
	}
	return 1;
}

sub write_png_to_file
{
	my $self = shift;
	my $file = shift;

	unless( $self -> { 'CREATED' } )
	{
		$self -> my_create();
	}
	my @res = $self -> { 'IMAGE' } -> out( force => 'png' );

	if( $res[ 0 ] )
	{
		unless( $file )
		{
			$file = tmpnam();
		}

		my $fh = undef;
		if( open( $fh, '>', $file ) )
		{
			
			my $flock_result = flock( $fh, LOCK_EX | LOCK_NB );
			if( $flock_result )
			{
				print $fh $res[ 0 ];
			} else
			{
				$file = undef;
			}
			close $fh;
		} else
		{
			$file = undef;
		}
	} else
	{
		$file = undef;
	}
	return $file;
}

sub captcha_uri
{
	my $self = shift();

	my $WOBJ = &Wendy::__get_wobj();

	my $rstr = $self -> get_public();
	my $dst_file = File::Spec -> catfile( CONF_VARPATH,
					      'hosts',
					      $WOBJ -> { 'HOST' } -> { 'host' },
					      'htdocs',
					      'mod',
					      'captcha',
					      'var',
					      $rstr . ".png" );
	my $sitepath = File::Spec -> catfile( 'mod',
					      'captcha',
					      'var',
					      $rstr . ".png" );

	unless( $self -> { 'TEXT' } )
	{
		$self -> set_text( undef );
	}

	$self -> write_png_to_file( $dst_file );
	my $c_uri = URI -> new();
	$c_uri -> scheme( 'http' );
	$c_uri -> host( $WOBJ -> { 'HOST' } -> { 'host' } );
	$c_uri -> path( $sitepath );

	return $c_uri -> as_string();
}

sub check_captcha
{
	my ( $public,
	     $text ) = @_;

	my $WOBJ = &Wendy::__get_wobj();
	my $dst_file = File::Spec -> catfile( CONF_VARPATH,
					      'hosts',
					      $WOBJ -> { 'HOST' } -> { 'host' },
					      'htdocs',
					      'mod',
					      'captcha',
					      'var',
					      escape_filename( $public ) . ".png" );
	my $rv = 0;

	if( unlink $dst_file )
	{
		my ( $pass, $tpublic ) = split( /_/, $public );
		$rv = md5_hex( $text . $pass ) eq $tpublic;
	}

	return $rv;
}

1;
