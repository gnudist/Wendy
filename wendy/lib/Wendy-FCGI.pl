#!/usr/bin/perl

# Using Wendy with FastCGI. EXPERIMENTAL

use strict;
use FCGI;

my $request = FCGI::Request();

while( $request -> Accept() >= 0 )
{
	print &Wendy::handler( $request );
}
exit( 0 );

################################################################################

package Wendy;

use File::Spec;
use Wendy::Config;
use lib File::Spec -> catdir( CONF_MYPATH, 'lib' );

use Wendy::Memcached;
use Wendy::Templates;
use Wendy::Hosts;
use Wendy::Db;
use Wendy::Util::File 'save_data_in_file_atomic';

use CGI;
use CGI::Cookie;

use Digest::MD5 'md5_hex';

our %WOBJ = ();

sub __get_wobj
{
	return \%WOBJ;
}

sub handler 
{
	my $r = shift;

	my ( $code, $msg, $ctype, $charset ) = ( 200, 'okay', 'text/html', 'utf-8' );

	my $FILE_TO_SEND = "";
	my $FILE_OFFSET = undef;
	my $FILE_LENGTH = undef;

	my $DATA_TO_SEND = "";
	my @HEADERS_TO_SEND = ();
	
	my %COOKIES = fetch CGI::Cookie;
	my $LANGUAGE = "";

	my $CCHEADERS = 0;
	my $CACHEPATH = "";
	my $CACHESTORE = "";
	my $CACHEHIT = 0;
	my $PROCRV = {};

	my $HANDLERPATH = ( &form_address( $ENV{ 'REQUEST_URI' } ) or 'root' );

	if( &cacheable_request() )
	{
		if( $ENV{ 'QUERY_STRING' } =~ /lng=(\w+)/i ) # well thats a bit dirty but faster
		{
			$LANGUAGE = $1;
		}
		
		unless( $LANGUAGE )
		{
			if( $COOKIES{ 'lng' } )
			{
				$LANGUAGE = $COOKIES{ 'lng' } -> value();
			}
		}

		if( $LANGUAGE )
		{
			my $t = &request_cache_hit( $LANGUAGE, $ENV{ "HTTP_HOST" }, $HANDLERPATH );
			if( $t )
			{
				$CACHEHIT = 1;
				$PROCRV = $t;
				goto PROCRV;
			}
		}
	}

	my $req = new CGI;
	&dbconnect();

	if( CONF_MEMCACHED )
	{
		&mc_init();
	}

	my %HTTP_HOST = &http_host_init( lc $ENV{ "HTTP_HOST" } );
	my %LANGUAGES = &get_host_languages( $HTTP_HOST{ "id" } );
	my %R_LANGUAGES = reverse %LANGUAGES;

	if( scalar keys %LANGUAGES > 1 )
	{
		$LANGUAGE = $req -> param( 'lng' );
		
		unless( $LANGUAGE )
		{
			if( $COOKIES{ 'lng' } )
			{
				$LANGUAGE = $COOKIES{ 'lng' } -> value();
			}
		}

		unless( $LANGUAGE )
		{
			if( $ENV{ 'HTTP_ACCEPT_LANGUAGE' } )
			{
				my %HAL = &parse_http_accept_language( $ENV{ 'HTTP_ACCEPT_LANGUAGE' } );
CETi8lj7Oz:
				foreach my $lng ( sort { $HAL{ $b } <=> $HAL{ $a } } keys %HAL )
				{
					if( exists $R_LANGUAGES{ $lng } )
					{
						$LANGUAGE = $lng;
						last CETi8lj7Oz;
					}
				}
			}
		}
		$CCHEADERS = 1;
	} # if more than 1 language for host, try to somehow determine most apropriate

	unless( $R_LANGUAGES{ $LANGUAGE } )
	{
		$LANGUAGE = $LANGUAGES{ $HTTP_HOST{ 'defaultlng' } };
	}

	if( $CCHEADERS )
	{
		my $lngcookie = new CGI::Cookie( -name  => 'lng',
						 -value => $LANGUAGE );

		push @HEADERS_TO_SEND, { 'Set-Cookie' => $lngcookie -> as_string() };
	}

	my $NOCACHE  = CONF_NOCACHE;
	my $CUSTOMCACHE = 0;

	my $FILENAME = File::Spec -> canonpath( File::Spec -> catfile( CONF_VARPATH, 'hosts', $HTTP_HOST{ "host" }, 'htdocs', $ENV{ "REQUEST_URI" } ) );

	if( -d $FILENAME )
	{
		1;
	} elsif( -f $FILENAME )
	{
		$code = 400;
		$msg = 'static is not served';
		$ctype = 'text/plain';
		$charset = undef;
		$DATA_TO_SEND = $msg;
		$NOCACHE = 1;

		goto WORKOUTPUT;
	} else
	{
		$code = 404;
		$msg = "404 not found";
		$HANDLERPATH = '404';
	}

	if( &cacheable_request() )
	{
		my $t = &request_cache_hit( $LANGUAGE, $HTTP_HOST{ "host" }, $HANDLERPATH );
		if( $t )
		{
			$CACHEHIT = 1;
			$PROCRV = $t;
			goto PROCRV;
		} else
		{
			$CACHEPATH = &form_cachepath( $HANDLERPATH, $LANGUAGE );
			$CACHESTORE = File::Spec -> catdir( CONF_VARPATH, 'hosts', $HTTP_HOST{ "host" }, 'cache' );
			$CACHEPATH = File::Spec -> catfile( $CACHESTORE, $CACHEPATH );
		}
	}

	my $TPLSTORE = File::Spec -> catdir( CONF_VARPATH, 'hosts', $HTTP_HOST{ "host" }, 'tpl'  );
	my $HOSTLIBSTORE = File::Spec -> catdir( CONF_VARPATH, 'hosts', $HTTP_HOST{ "host" }, 'lib' );
	my $PATHHANDLERSRC = File::Spec -> catfile( $HOSTLIBSTORE, $HANDLERPATH . ".pl" );
	my $METAHANDLERSRC = File::Spec -> catfile( $HOSTLIBSTORE, "meta.pl" );

	%WOBJ = ( COOKIES    => \%COOKIES,
		  REQREC     => $r,
		  CGI        => $req,
		  DBH        => &dbconnect(),
		  HOST       => \%HTTP_HOST,
		  LNG        => $LANGUAGE,
		  RLNGS      => \%R_LANGUAGES,
		  TPLSTORE   => $TPLSTORE,
		  HPATH      => $HANDLERPATH,
		  HANDLERSRC => $PATHHANDLERSRC );
	
	&unset_macros();

	my $handler_called = 0;

	{
		my @handlers = ( $PATHHANDLERSRC,
				 $METAHANDLERSRC );
		my $handlername = 'wendy_handler';

HANDLERSLOOP:
		foreach my $srcfile ( @handlers )
		{
			if( -f $srcfile )
			{
				no strict "refs";

				my $full_handler_name = join( '::', ( &form_address( $HTTP_HOST{ 'host' } ),
								      $HANDLERPATH,
								      $handlername ) );

				unless( exists &{ $full_handler_name } )
				{
					require $srcfile;
				}

				# thats a thin place, in case of error in source file we'll crash

				$PROCRV = &{ $full_handler_name }( \%WOBJ );
				$handler_called = 1;

				unless( ref( $PROCRV ) )
				{
					my $t_procrv = { 'data' => $PROCRV };
					$PROCRV = $t_procrv;
				}
				last HANDLERSLOOP;
			}
		}
	}

	unless( $handler_called )
	{
		$PROCRV = &template_process();
	}

	my $app_output = '';

PROCRV:
	if( $PROCRV -> { "ctype" } )
	{
		$CUSTOMCACHE = 1;
		$ctype = $PROCRV -> { "ctype" };
	}

	if( $PROCRV -> { "charset" } )
	{
		$CUSTOMCACHE = 1;
		$charset = $PROCRV -> { "charset" };
	}
	
	if( $PROCRV -> { "msg" } )
	{
		$CUSTOMCACHE = 1;
		$msg = $PROCRV -> { "msg" };
	}

	if( $PROCRV -> { "code" } )
	{
		$CUSTOMCACHE = 1;
		$code = $PROCRV -> { "code" };
	}
	
	if( $PROCRV -> { "data" } )
	{
		$DATA_TO_SEND = $PROCRV -> { "data" };
	}
	
	if( $PROCRV -> { "file" } )
	{
		$FILE_TO_SEND = $PROCRV -> { "file" };

		if( $PROCRV -> { "file_offset" } )
		{
			$FILE_OFFSET = $PROCRV -> { "file_offset" };
		}
		
		if( $PROCRV -> { "file_length" } )
		{
			$FILE_LENGTH = $PROCRV -> { "file_length" };
		}
	}

	if( ref( $PROCRV -> { "headers" } ) )
	{
		$CCHEADERS = 1;

		if( ref( $PROCRV -> { "headers" } ) eq 'HASH' )
		{
			foreach my $header ( keys %{ $PROCRV -> { "headers" } } )
			{
				push @HEADERS_TO_SEND, { $header => $PROCRV -> { "headers" } -> { $header } };
			}
		} elsif( ref( $PROCRV -> { "headers" } ) eq 'ARRAY' )
		{
			my @t = @{ $PROCRV -> { "headers" } };
			while( my $key = shift @t )
			{
				my $value = shift @t;
				push @HEADERS_TO_SEND, { $key => $value };
			}
		}
	}

	if( exists $PROCRV -> { "ttl" } )
	{
		if( $PROCRV -> { "ttl" } )
		{
			$PROCRV -> { "expires" } = time() + $PROCRV -> { "ttl" };
		} else
		{
			$PROCRV -> { 'nocache' } = 1;
		}
		
		delete $PROCRV -> { "ttl" };
	}

	if( $PROCRV -> { "nocache" } )
	{
		$NOCACHE = 1;
	}

	if( $PROCRV -> { "expires" } )
	{
		$CUSTOMCACHE = 1;
	}


WORKOUTPUT:
	if( ( $CACHEHIT == 0 ) and ( $NOCACHE == 0 ) and $CACHEPATH )
	{

		if( $CCHEADERS )
		{
			my $CCFILE = $CACHEPATH . ".headers";
			&save_data_in_file_atomic( join( ':::', map { join( ":::", ( %$_ ) ) } @HEADERS_TO_SEND ), $CCFILE );
			delete $PROCRV -> { "headers" };
		}
		
		if( $CUSTOMCACHE )
		{
			my $CCFILE = $CACHEPATH . ".custom";
			delete $PROCRV -> { "data" };
			&save_data_in_file_atomic( join( ':::', %$PROCRV ), $CCFILE );
		}

		&save_data_in_file_atomic( $DATA_TO_SEND, $CACHEPATH );
	}

	# $r -> status( $code );
	# $r -> status_line( join( ' ', ( $code, $msg ) ) );



	$app_output .= "Status: " . join( ' ', ( $code, $msg ) ) . "\n";

	if( $ctype )
	{
		#$r -> content_type( $ctype . ( $charset ? '; charset=' . $charset : '' ) );
		$app_output .= "Content-Type: ". $ctype . ( $charset ? '; charset=' . $charset : '' ) . "\n";
	}

	if( scalar @HEADERS_TO_SEND )
	{
		foreach my $header ( @HEADERS_TO_SEND )
		{
			my ( $key, $value ) = %$header;
			#$r -> headers_out -> { $key } = $value;
			$app_output .= $key . ": " . $value;
		}
	}
	$app_output .= "\n";
	# unless( $r -> header_only() )
	# {
		if( $FILE_TO_SEND )
		{
		 	#$r -> sendfile( $FILE_TO_SEND, $FILE_OFFSET, $FILE_LENGTH );
			my $fh = undef;
			if( open( $fh, '<', $FILE_TO_SEND ) )
			{
				if( $FILE_OFFSET )
				{
					seek( $fh, $FILE_OFFSET, 0 );
				}
				my $buf = '';
				while( read( $fh, $buf, 4096 ) )
				{
					$app_output .= $buf;
				}
				close $fh;
			} else
			{
				die 'could not open ' . $FILE_TO_SEND . ': ' . $!;
			}
		}
		
		if( $DATA_TO_SEND )
		{
			$app_output .= $DATA_TO_SEND;
		}
	# }

WORKFINISHED:
	&dbdisconnect();
	&wdbdisconnect();

	%WOBJ = ();

	return $app_output;
}

sub parse_http_accept_language
{
	my $alstr = shift;
	$alstr =~ s/\s//g;
	my @lq = split ",", $alstr;
	my %outcome = ();

	foreach ( @lq )
	{
		my ( $lng, $q ) = split ";q=", $_;
		$q = 1 unless $q;
		$outcome{ $lng } = $q;
	}
	return %outcome;
}

sub read_customcache_file
{
	my $file = shift;

	my $cfh = undef;
	my @rv = ();

	if( open( $cfh, "<", $file ) )
	{
		while( my $line = <$cfh> )
		{
			chomp $line;
			push @rv, split( /:::/, $line );
			
		}
		close $cfh;
	}

	return @rv;
}

sub running_in_https
{
	my $rv = 0;

	if( $ENV{ 'HTTP_HTTPS' } or $ENV{ 'HTTPS' } )
	{
		$rv = 1;
	}

	return $rv;
}

sub cacheable_request
{
	my $rv = 0;
	if( $ENV{ "REQUEST_METHOD" } eq "GET" )
	{
		$rv = 1;
	}
	return $rv;
}

sub form_cachepath
{
	my ( $prepath, $l ) = @_;

	my $params_str = $ENV{ 'QUERY_STRING' };

	my $rv = $prepath . md5_hex( $params_str ) . $l;
	
	if( &running_in_https() )
	{
		$rv .= '_S';
	}
	return $rv;
}

sub request_cache_hit
{
	my ( $lng, $hostname, $hp ) = @_;

	my $rv = undef;

	my $cachepath = &form_cachepath( $hp, $lng );
		
	my $cachestore = File::Spec -> catdir( CONF_VARPATH, 'hosts', $hostname, 'cache' );
	$cachepath = File::Spec -> catfile( $cachestore, $cachepath );
	
	if( -f $cachepath )
	{
		$rv = {};
		my $ccfile = $cachepath . ".custom";
		
		if( -f $ccfile )
		{
			my $cfh = undef;
			my %procrv = &read_customcache_file( $ccfile );
			$rv = \%procrv;
			
			if( $rv -> { "expires" }
			    and
			    ( $rv -> { "expires" } < time() ) )
			{
				# this cache is expired, do not use it!
				#if( &getla() < 2.0 )
				{
					unlink $cachepath;
					unlink $cachepath . ".custom";
					unlink $cachepath . ".headers";
					
					return undef;
				}
			}
		}
		
		$ccfile = $cachepath . ".headers";
		
		if( -f $ccfile )
		{
			my $cfh;
			my @cheaders = &read_customcache_file( $ccfile );
			$rv -> { "headers" } = \@cheaders;
		}
		$rv -> { 'file' } = $cachepath;
	}
	
	return $rv;
}

1;
