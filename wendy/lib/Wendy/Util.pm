#!/usr/bin/perl

use strict;

package Wendy::Util;

require Exporter;

use Wendy::Db;
use Wendy::Memcached;

use File::Spec;
use File::Temp;
use LWP::UserAgent;
use Crypt::SSLeay;
use HTTP::Request::Common;
use HTTP::Headers;
use URI;
use Data::Validate::URI 'is_uri';
use MIME::Lite;
use MIME::Base64;

our @ISA         = qw( Exporter );
our @EXPORT      = qw( build_directory_tree
		       meta_get_records
		       meta_get_record
		       abs2rel_compat
		       in );

our @EXPORT_OK   = qw( build_directory_tree
		       meta_get_records
		       meta_get_record
		       in
		       download_url
		       rand_array
		       abs2rel_compat
		       send_mail );
our %EXPORT_TAGS = ( default => [ qw( ) ] );
our $VERSION     = 1.00;


sub abs2rel_compat
{
	my ( $rel, $abs ) = @_;
        my $res = File::Spec -> abs2rel( $rel, $abs );

        return ( $res eq '.' ? '' : $res );
}

sub in # checks if element in array or not :)
{
	my $el = shift;

	foreach ( @_ )
	{
		return 1 if $_ eq $el;
	}
	return 0;
}

sub build_directory_tree
{
	my $path = shift;
	my @outcome = ();
	my $dh = undef;

	if( opendir( $dh, $path ) )
	{
		push @outcome, $path;

		while( my $entry = readdir( $dh ) )
		{
			unless( index( $entry, "." ) )
			{
				next;
			}

			my $fn = File::Spec -> catfile( $path, $entry );

			if( ( -d $fn )
			    and
			    ( not -l $fn ) )
			{
				push @outcome, &build_directory_tree( $fn );

			} else
			{
				push( @outcome, $fn );
			}
		}
		closedir( $dh );
	}

	return @outcome;
}

sub meta_get_records
{
	my %args = @_;
	my %outcome = ();

	my ( $table,
	     $fields,
	     $where,
	     $limit,
	     $offset,
	     $orderby,
	     $ordermode,
	     $memcache,
	     $mc_timeout,
	     $debug ) = @args{ 'Table',
			       'Fields',
			       'Where',
			       'Limit',
			       'Offset',
			       'OrderField',
			       'OrderMode',
			       'Memcache',
			       'MemcacheTime',
			       'Debug' };

	my $fieldspart = "";

	if( defined $fields )
	{
		$fieldspart = join( ", ", @$fields );
	} else
	{
		$fieldspart = '*';
	}

	my $sql = "SELECT " .
	          $fieldspart .
		  " FROM " .
		  $table .
		  ( $where ? " WHERE " . $where : '' ) .
		  ( $limit ? " ORDER BY " . ( $orderby ? $orderby : 'id' ) . ' ' . ( $ordermode ? $ordermode : 'DESC' ) . " LIMIT " . int( $limit ) : '' ) .
		  ( $offset ? " OFFSET " . int( $offset ) : '' );

	if( $debug )
	{
		return $sql;
	}

	my $qid = "";

	if( $memcache )
	{
		$qid = $sql;
		my $cached = &mc_get( $qid );

		if( defined $cached )
		{
			return %$cached;
		}
	}

	my $sth = &dbprepare( $sql );
	my $error = 0;
	$sth -> execute() or $error = 1;

	if( $error )
	{
		die 'SQL error: ' . $sql . ' ' . &dbgeterror();
	}

	while( my $data = $sth -> fetchrow_hashref() )
	{
		$outcome{ $data -> { "id" } } = $data;
	}

	$sth -> finish();

	if( $memcache )
	{
		&mc_set( $qid, \%outcome, ( $mc_timeout or 600 ) );
	}

	return %outcome;

}

sub meta_get_record
{
	my %args = @_;

	my ( $table,
	     $fields,
	     $where,
	     $limit,
	     $orderby,
	     $ordermode,
	     $memcache,
	     $mc_timeout,
	     $debug ) = @args{ 'Table',
			       'Fields',
			       'Where',
			       'Limit',
			       'OrderField',
			       'OrderMode',
			       'Memcache',
			       'MemcacheTime',
			       'Debug' };

	my $fieldspart = "";

	if( defined $fields )
	{
		$fieldspart = join( ", ", @$fields );
	} else
	{
		$fieldspart = '*';
	}

	my $sql = "SELECT " .
	          $fieldspart .
		  " FROM " .
		  $table .
		  ( $where ? " WHERE " . $where : '' ) .
		  ( $limit ? " ORDER BY " . ( $orderby ? $orderby : 'id' ) . ' ' . ( $ordermode ? $ordermode : 'DESC' ) . " LIMIT " . int( $limit ) : '' );

	if( $debug )
	{
		return $sql;
	}

	my $qid = "";

	if( $memcache )
	{
		$qid = $sql;
		my $cached = &mc_get( $qid );
		
		if( defined $cached )
		{
			return $cached;
		}
	}


	my $rowrec = &dbselectrow( $sql );

	if( $memcache )
	{
		&mc_set( $qid, $rowrec, ( $mc_timeout or 600 ) );
	}

	return $rowrec;
}

sub download_url
{
	my %args = @_;

	my ( $url,
	     $referer,
	     $agent ) = @args{ "URL",
			       "Referer",
			       "Agent" };
	
	my $MAX_REDIR = 7;
	
	my $ua = LWP::UserAgent -> new( agent                 => $agent,
					max_redirect          => $MAX_REDIR,
					timeout               => 30,
					protocols_allowed     => [ 'ftp', 'http', 'https' ],
					requests_redirectable => [ 'GET', 'HEAD' ] );

	my $response = undef;
	my $outcome = undef;
	my $rq_size = undef;

	my $uuri = URI -> new( $url );
	
	$response = $ua -> get( $url,
				Referer => $referer );
	
	if( $response -> is_redirect() )
	{
		my $newlocation = $response -> header( 'Location' );
		
		unless( &is_uri( $newlocation ) )
		{
			$uuri -> path( $newlocation );
			$newlocation = $uuri -> canonical();
		}
		
		$outcome = {
			code     => $response -> code(),
			msg      => 'redirect',
			location => $newlocation
		    };
		return $outcome;
	} elsif( $response -> is_success() )
	{
		my ( $tfh, $tfn ) = tmpnam();
		print $tfh $response -> content();
		
		unless( $rq_size )
		{
			$rq_size = -s $tfn;
		}
		
		my $ctype = scalar $response -> header( "Content-Type" );
		
		my @ctypes = split( /[,\s]+/, $ctype );
		my ( $type, $chset );
		
VhUmZOI3Z2PQyQp:
		foreach ( @ctypes )
		{
			( $type, $chset ) = split( /[;\s]+/, $_ );
			last VhUmZOI3Z2PQyQp;
		}
		
		$outcome = {
			code     => $response -> code(),
			size     => $rq_size,
			ctype    => ( $type or 'application/octet-stream' ),
			file     => $tfn,
			msg      => 'ok'
		    };
		return $outcome;
	} else
	{
		$outcome = {
			code     => $response -> code(),
			msg      => 'bad'
			    
		    };
		return $outcome;
	}

	$outcome = {
		code     => $response -> code(),
		msg      => 'err'
	    };
	return $outcome;
}

sub rand_array
{
	return $_[ int( rand( $#_ ) + 0.5 ) ];
}

sub send_mail
{
	my %args = @_;

	my ( $from,
	     $to,
	     $subject,
	     $rsubj,
	     $text ) = @args{ "From",
			      "To",
			      "Subject",
			      "RawSubj",
			      "Text" };

	if( $rsubj )
	{
		$subject = '=?UTF-8?b?' .
		           encode_base64( $rsubj, '' ) .
			   '?=';
	}

	my $message = MIME::Lite -> new( From    => $from,
					 To      => $to,
					 Subject => $subject,
					 Type    => 'multipart/mixed' );

	my $textpart = MIME::Lite -> new( Type     => 'TEXT',
					  Encoding => '8bit',
					  Charset  => 'UTF-8',
					  Data => $text );
				
	$textpart -> attr( "content-type.charset" => "UTF-8" );
	$message -> attach( $textpart );
	eval { $message -> send() };
	return 0;
}

1;
