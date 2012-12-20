#!/usr/bin/perl

use strict;

package Wendy::Templates;

require Exporter;

use Wendy::Config;
use Wendy::Db;
use Wendy::Procs;
use Wendy::Util ( 'in', 'download_url', 'meta_get_records', 'meta_get_record' );
use Wendy::Util::String 'despace';
use Wendy::DataCache;

use File::Spec;
use XML::Quote;
use URI;

our @ISA         = qw( Exporter );
our @EXPORT      = qw( template_process
                       template_exists
                       data_process
		       load_macros
		       sload_macros
		       unset_macros
		       add_replace
		       get_replace
		       kill_replace
		       quoter );
our @EXPORT_OK   = @EXPORT;
our %EXPORT_TAGS = ( default => [ qw( ) ] );
our $VERSION     = 1.00;

our %REPLACES = ();

my $__replace_regexp = qr/\[([A-Z_0-9\-]+)\]/;
my $__functional_regexp = qr/^(PROC|TEMPLATE|TEMPLATEC|INCLUDE|TEMPLATEFF|URL|URLFF|LOAD|CTYPE|TTL|CODE|HEADER|LANGUAGE):([\w\/\-:\.\;\=,\s\+\?\&]+)/;

sub quoter
{
	my $str = shift;
	$str =~ s/$__replace_regexp/[ $1 ]/g;
	$str =~ s/$__functional_regexp/ $1:$2/g;
	return $str;
}

sub template_exists
{
	my $tname = shift;
	my $WOBJ = &Wendy::__get_wobj();
	my $tplfile = File::Spec -> catfile( $WOBJ -> { "TPLSTORE" }, ( $tname or $WOBJ -> { "HPATH" } ) );
	my $rc = 0;

	if( -f $tplfile )
	{
		$rc = 1;
	}
	return $rc;
}

sub template_process
{
	my $WOBJ = shift;

	my $force_template_name = '';

	if( defined $WOBJ )
	{
		unless( ref( $WOBJ ) )
		{
			$force_template_name = $WOBJ;
			$WOBJ = &Wendy::__get_wobj();
		}

	} else
	{
		$WOBJ = &Wendy::__get_wobj();
	}

	my $tfh = undef;

	my $tplfile = File::Spec -> catfile( $WOBJ -> { "TPLSTORE" }, ( $force_template_name or $WOBJ -> { "HPATH" } ) );

	open( $tfh, "<", $tplfile ) or die "cant open template file " . $tplfile . $!;
	my @OUTPUT = <$tfh>;
	close $tfh;

	return &data_process( \@OUTPUT );
}

sub data_process
{
	my $WOBJ = shift;
	my $tdata = undef;

	my $joinstr = '';

	if( defined $WOBJ )
	{
		if( ref( $WOBJ ) eq 'ARRAY' )
		{
			$tdata = $WOBJ;
			$WOBJ = &Wendy::__get_wobj();
		} elsif( not ref( $WOBJ ) )
		{
			my @t = split( /[\x0d\x0a]+/, $WOBJ );
			$tdata = \@t;
			$WOBJ = &Wendy::__get_wobj();
			$joinstr = "\x0a"; # unix newline character
		}
	} else
	{
		$WOBJ = &Wendy::__get_wobj();
	}
	
	unless( $tdata )
	{
		if( exists $WOBJ -> { 'TDATA' } )
		{
			$tdata = $WOBJ -> { 'TDATA' };
			delete $WOBJ -> { 'TDATA' };
		} else
		{
			die 'data_process without tdata';
		}
	}

	my %outcome = ();
	my $customheaders = {};
	my $do_headers = 0;

	my @OUTPUT = @$tdata;

	&apply_replaces( \@OUTPUT );

	my @NROUTPUT = ();

VNR8cv0oP5bIFmDL:
	foreach my $tline ( @OUTPUT )
	{
		if( $tline =~ $__functional_regexp )
		{
			$tline = "";
			my ( $keyword, $argument ) = ( $1, $2 );
			
			if( $keyword eq 'PROC' )
			{
				$argument =~ s/\s//g;
				my ( $procname, $procargs ) = split( /:/, $argument );
				my $proc = &get_proc( Name => $procname );

				if( scalar keys %$proc )
				{
					if( $procargs )
					{
						$ENV{ "WENDY_PROC_ARGS" } = $procargs;
					}
					my $outcome = eval ( $proc -> { ${ [ keys %$proc ] }[ 0 ] } -> { "body" } );

					if( $procargs )
					{
						delete $ENV{ "WENDY_PROC_ARGS" };
					}

					if( $@ )
					{
						$outcome = "ERROR WITH " . $procname . ":\n" . $@ . "\n";
					}
					push @NROUTPUT, $outcome;
				}


			} elsif( $keyword eq 'CTYPE' )
			{
				$argument =~ s/\s//g;
				$outcome{ 'ctype' } = $argument;

			} elsif( $keyword eq 'CODE' )
			{ 
				$outcome{ 'code' } = int( $argument );

			} elsif( $keyword eq 'HEADER' )
			{
				$do_headers = 1;
				$argument =~ s/\s//g;
				my ( $header_name, $header_value ) = split( /\Q:\E/, $argument, 2 );
				$customheaders -> { $header_name } = $header_value;
			} elsif( $keyword eq 'TTL' )
			{ 
				$outcome{ 'ttl' } = int( $argument );

			} elsif( ( $keyword eq 'URL' )
				 or
				 ( $keyword eq 'URLFF' ) )
			{ 
				$argument =~ s/\s//g;
				my $outcome = &download_url( URL => $argument,
							     Agent => 'Wendy site engine' );

				if( $outcome -> { 'msg' } eq 'ok' )
				{
					my $data = "";
					if( $outcome -> { "data" } )
					{
						$data = $outcome -> { "data" };
					} elsif( $outcome -> { "file" } )
					{
						my $tfh = undef;

						if( open( $tfh, '<', $outcome -> { "file" } ) )
						{
							push @NROUTPUT, join( '', <$tfh> );
							close $tfh;
							unlink $outcome -> { "file" };
						}
					}

					if( $keyword eq 'URLFF' )
					{
						$outcome{ "ctype" } = $outcome -> { "ctype" };
					}
				} else
				{
					push @NROUTPUT, 'ERROR DOWNLOADING ' .
					                $argument .
							' (' .
							$outcome -> { 'code' } .
							')';
				}

			} elsif( ( $keyword eq 'TEMPLATE' )
				 or
				 ( $keyword eq 'TEMPLATEFF' )
				 or
				 ( $keyword eq 'TEMPLATEC' ) )
			{
				$argument =~ s/\s//g;

				my $bbkhost = '';
				my $bbkstore = '';

				if( index( $argument, ':' ) != -1 )
				{
					my ( $maybehost, $tpl ) = split( /:/, $argument );

					my $hostrec = &meta_get_record( Table => 'host',
									Where => sprintf( "host=%s", &dbquote( $maybehost ) ),
									Memcache => CONF_MEMCACHED,
									Fields => [ 'id' ] );

					if( $hostrec )
					{
						$bbkhost = $WOBJ -> { 'HOST' } -> { 'host' }; # only hostname is changed
						$bbkstore = $WOBJ -> { "TPLSTORE" };
						$WOBJ -> { 'HOST' } -> { 'host' } = $maybehost;


						$WOBJ -> { 'TPLSTORE' } = File::Spec -> catdir( CONF_VARPATH,
												'hosts',
												$WOBJ -> { 'HOST' } -> { 'host' },
												'tpl' );

						$argument = $tpl;
					}
				}

				my @templates_used = ();

				if( defined $WOBJ -> { "__tpllist" } )
				{
					@templates_used = @{ $WOBJ -> { "__tpllist" } };
				}
				unless( &in( $argument, @templates_used ) )
				{
					push @templates_used, $argument;
					$WOBJ -> { "__tpllist" } = \@templates_used;

					unless( $WOBJ -> { "TRUE_HPATH" } )
					{
						$WOBJ -> { "TRUE_HPATH" } = $WOBJ -> { "HPATH" };
					}

					$WOBJ -> { "HPATH" } = $argument;
					
					my $proct = {};
					my $cachehit = 0;
					my $cacheid = '';

					if( $keyword eq 'TEMPLATEC' )
					{
						$cacheid = $WOBJ -> { 'HOST' } -> { 'host' } .
						           $WOBJ -> { 'HPATH' } .
							   $WOBJ -> { 'LNG' };
						my $cached = &datacache_retrieve( $cacheid );
						if( $cached )
						{
							$cachehit = 1;
							$proct -> { 'data' } = $cached;
						}
					}

					unless( $cachehit )
					{
						$proct = &template_process( $WOBJ );
					}

					push @NROUTPUT, $proct -> { "data" };

					if( $keyword eq 'TEMPLATEFF' )
					{
						foreach my $kid ( keys %$proct )
						{
							$outcome{ $kid } = $proct -> { $kid };
						}
					} elsif( ( $keyword eq 'TEMPLATEC' )
						 and
						 ( $cachehit == 0 ) )
					{
						&datacache_store( Id => $cacheid,
								  Data => $proct -> { 'data' },
								  TTL => $proct -> { 'ttl' } );
					}

					$WOBJ -> { "HPATH" } = $WOBJ -> { "TRUE_HPATH" };
				}

				if( $bbkhost )
				{
					$WOBJ -> { 'HOST' } -> { 'host' } = $bbkhost;
					$WOBJ -> { 'TPLSTORE' } = $bbkstore;
				}

			} elsif( $keyword eq 'INCLUDE' )
			{
				$argument =~ s/\s//g;
				my $atemplate = File::Spec -> catfile( $WOBJ -> { "TPLSTORE" },
								       $argument );
				my $tfh = undef;

				if( open( $tfh, "<", $atemplate ) )
				{
					my @ATE = <$tfh>;
					close( $tfh );
					push @NROUTPUT, @ATE;
				} else
				{
					push @NROUTPUT, '<pre>Cant open include file ' . $atemplate . ': ' . $! . '</pre>';
				}

			} elsif( $keyword eq 'LOAD' )
			{
				$argument =~ s/\s//g;

				if( index( $argument, ':' ) != -1 )
				{
					my ( $host, $addr ) = split( /:/, $argument );
					
					my $hostrec = &meta_get_record( Table => 'host',
									Where => sprintf( "host=%s", &dbquote( $host ) ),
									Memcache => CONF_MEMCACHED,
									Fields => [ 'id' ] );

					if( $hostrec )
					{
						&load_macros( HostId  => $hostrec -> { 'id' },
							      Address => $addr,
							      Lng     => $WOBJ -> { "RLNGS" } -> { $WOBJ -> { "LNG" } } );
						
					} else
					{
						&load_macros( HostId => $WOBJ -> { "HOST" } -> { "id" },
							      Address => $argument,
							      Lng => $WOBJ -> { "RLNGS" } -> { $WOBJ -> { "LNG" } } );
					}
				} else
				{

					if( $argument eq '_this' )
					{
						$argument = ( $WOBJ -> { "TRUE_HPATH" } or $WOBJ -> { "HPATH" } );
					}

					&load_macros( HostId => $WOBJ -> { "HOST" } -> { "id" },
						      Address => $argument,
						      Lng => $WOBJ -> { "RLNGS" } -> { $WOBJ -> { "LNG" } } );
				}
			}  elsif( $keyword eq 'LANGUAGE' )
			{
				my @l = grep { $_ } split( /:/, &despace( $argument ) );
				if( @l )
				{
					unless( &in( $WOBJ -> { 'LNG' }, @l ) )
					{
						my $reload_url = 'http';
						
						if( $ENV{ 'HTTP_HTTPS' } or $ENV{ 'HTTPS' } )
						{
							$reload_url = 'https';
						}
						$reload_url .= '://' . $WOBJ -> { 'HOST' } -> { 'host' };
						$reload_url .= $ENV{ 'REQUEST_URI' };
						
						my $u = URI -> new( $reload_url );
						my %h = $u -> query_form();
						$h{ 'lng' } = $l[ 0 ];
						$u -> query_form( %h );

						return { nocache => 1,
							 code => 302,
							 headers => { Location => $u -> as_string() } };
					}
				}
			}
		}
		push @NROUTPUT, $tline;
	}

	&apply_replaces( \@NROUTPUT );

	if( $do_headers )
	{
		$outcome{ "headers" } = $customheaders;
	}

	$outcome{ "data" } = join( $joinstr, @NROUTPUT );

	return \%outcome;
}

sub apply_replaces # replaces are meant to be uppercase strings inside squarebrackets, see $__replace_regexp
{
	my $ol = shift;

	my $left_bracket_replace = 'G1u2U3A465k6z7x8L9P';  # '&#91;'
	my $right_bracket_replace = 'H9u8U7A665k4z3x2L1P'; # '&#93;'

	my $max_iter = 100;

	foreach my $line ( @$ol )
	{
		my $get_brackets_back = 0;

		my $i = 0;

uQpzlN9rCCiPzh2T:
		while( $line =~ $__replace_regexp )
		{
			my $mac = $1;
			my $replace = $left_bracket_replace . $mac . $right_bracket_replace;

			if( exists $REPLACES{ $mac } )
			{
				$replace = $REPLACES{ $mac };
			} else
			{
				$get_brackets_back = 1;
			}
			$line =~ s/\[$mac\]/$replace/g;

			if( $i > $max_iter )
			{
				last uQpzlN9rCCiPzh2T;
			}

		} continue { $i ++ }

		if( $get_brackets_back )
		{
			$line =~ s/$left_bracket_replace/[/g;
                        $line =~ s/$right_bracket_replace/]/g;
		}
	}
}

sub sload_macros
{
	my $address = shift;
	my $WOBJ = &Wendy::__get_wobj();

	unless( $address )
	{
		$address = $WOBJ -> { "HPATH" };
	}

 	&load_macros( HostId => $WOBJ -> { "HOST" } -> { "id" },
 		      Address => $address,
 		      Lng => $WOBJ -> { "RLNGS" } -> { $WOBJ -> { "LNG" } } );

	return 1;
}

sub load_macros
{
	my %args = @_;

	my ( $hostid,
	     $address,
	     $language ) = @args{ "HostId",
				  "Address",
				  "Lng" };

	my $where = "1=1";

	if( $hostid )
	{
		$where .= " AND host=" . &dbquote( $hostid );
	}

	if( $address )
	{
		$where .= " AND address=" . &dbquote( $address );
	}

	if( $language )
	{
		$where .= " AND lng=" . &dbquote( $language );
	}

	if( $address eq 'SYSTEM:lng' )
	{
		my $WOBJ = &Wendy::__get_wobj();
		$REPLACES{ 'WENDY_LNG' } = $WOBJ -> { 'LNG' };
		$REPLACES{ 'WENDY_LNG_ID' } = $WOBJ -> { 'RLNGS' } -> { $WOBJ -> { 'LNG' } };
		
	} elsif( $address eq 'SYSTEM:envq' )
	{
		my $WOBJ = &Wendy::__get_wobj();
		foreach my $env ( keys %ENV )
		{
			$REPLACES{ 'WENDY_ENV_' . uc( $env ) } = xml_quote( $ENV{ $env } );
		}
		$REPLACES{ 'WENDY_ENV_HOST' } = $WOBJ -> { 'HOST' } -> { 'host' };
	} elsif( $address eq 'SYSTEM:scheme' )
	{
		my $scheme = 'http';
		if( $ENV{ 'HTTPS' } or $ENV{ 'HTTP_HTTPS' } )
		{
			$scheme = 'https';
		}
		$REPLACES{ 'SYSTEM_SCHEME' } = $scheme;
	} else
	{
		my %recs = &meta_get_records( Table => 'macros',
					      Fields => [ 'id', 'name', 'body' ],
					      Where => $where,
					      Memcache => CONF_MEMCACHED );
		
		
		foreach my $mid ( keys %recs )
		{
			$REPLACES{ $recs{ $mid } -> { "name" } } = $recs{ $mid } -> { "body" };
		}
	}
	1;
}

sub unset_macros
{

	if( scalar @_ )
	{
		map { delete $REPLACES{ $_ } } @_;
	} else
	{
		%REPLACES = ();
	}
	1;
}

sub add_replace
{
	my %args = @_;

	foreach my $name ( keys %args )
	{
		$REPLACES{ $name } = $args{ $name };
	}

	1;
}

sub get_replace
{
	my $name = shift;

	return $REPLACES{ $name };
}

sub kill_replace
{
	return &unset_macros( @_ );
}

1;
