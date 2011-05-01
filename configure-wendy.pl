#!/usr/bin/perl

use strict;
use lib "wendy/lib";

use Term::ReadLine;
use File::Touch;
use File::Spec;
use File::Temp;
use Wendy::Util 'perl_module_available';
use Wendy::Util::File 'save_data_in_file_atomic';
use Wendy::Hosts 'form_address';
use Cwd;

my @reqlist = qw(
Apache::DBI
Apache2::Access
Apache2::Connection
Apache2::RequestIO
Apache2::RequestRec
Apache2::RequestUtil
Cache::Memcached
CGI
CGI::Cookie
Crypt::SSLeay
Data::Dumper
Data::Validate::URI
DBD::Pg
DBI
Digest::MD5
Fcntl
File::Basename
File::Spec
File::Path
File::Temp
File::Touch
File::Util
HTTP::Headers
HTTP::Request::Common
LWP::UserAgent
MIME::Base64
MIME::Types
URI
XML::Quote
MIME::Lite
DateTime
		 );

my @notfounds = ();

foreach my $name ( @reqlist )
{
	print "Checking requirement " . $name . "...";

	my $res = "ok";

	unless( &perl_module_available( $name ) )
	{
		$res = "fail";
		push @notfounds, $name;
	}
	print $res, "\n";
}


if( scalar @notfounds )
{
	print "Following modules are required by Wendy, but not found on this system:\n\n",
	      join( "\n", @notfounds ),
	      "\n\nCan not continue.";
	exit( 0 );
}

print <<EOF;

Welcome!

Welcome to Wendy configuration script. Just answer few simple
questions and I will generate some files in hereby 'wendy' directory;

This script will not actually install any files over your hard disk,
just only make corrections in distribution files so they point to
right locations.

You will have to modify your Apache configuration file, or startup.pl
file yourself.


EOF

my $term = new Term::ReadLine '';
my $prompt = "Press enter to continue...";
$term -> readline( $prompt );

my $wendysdir = 'wendy';
my $configflag = '.configured';
$configflag = File::Spec -> catfile( $wendysdir, $configflag );

{ # do some checks
	
	unless( -d $wendysdir )
	{
		print <<EOF;

Distribution directory not found. Be sure to download and extract
Wendy correctly. See README.txt file.

EOF

                exit( 1 );
	}

	if( -f $configflag )
	{
		print <<EOF;

Already configured. To re-configure Wendy, completely remove $wendysdir directory
and re-extract distribution archive.

EOF
                exit( 2 );
	}
}

my @questions = (
		 {
			 desc  => 'Enter the place where Wendy will be installed:',
			 key   => '%WENDY_INSTALLATION_DIRECTORY%',
			 default => '/var/www/wendy',
			 oblig => 'yes'
		 },
		 {
			 desc  => 'Enter default host name Wendy will answer on:',
			 key   => '%DEFAULT_HOST%',
			 oblig => 'yes'
		 },
		 {
			 desc    => 'Enter database host:',
			 key     => '%DATABASE_HOST%',
			 default => '127.0.0.1',
			 oblig   => 'yes'
		 },

		 {
			 desc    => 'Enter database port:',
			 key     => '%DATABASE_PORT%',
			 default => '5432',
			 oblig   => 'yes'
		 },

		 {
			 desc    => 'Enter DB name:',
			 key     => '%DATABASE_NAME%',
			 default => 'wendysdb',
			 oblig   => 'yes'
		 },
		 {
			 desc    => 'Enter database user name:',
			 key     => '%DATABASE_USER%',
			 default => 'wendy',
			 oblig   => 'yes'
		 },
		 {
			 desc    => 'Enter database password:',
			 key     => '%DATABASE_PASSWORD%',
			 default => 'itsme',
			 oblig   => 'yes'
		 },

		 {
			 desc    => 'Enter root user password (admin interface is located at http://www.yourhost.com/admin/):',
			 key     => '%ROOT_PASSWORD%',
			 default => 'toor',
			 oblig   => 'yes'
		 },

		 );
my %data = ();

my $qno = 1;
my $qcnt = scalar @questions;

KSxcfevU:
foreach my $question ( @questions )
{

	print "\n\n", "Question ", $qno, " of ", $qcnt, "\n\n";

	my $temp_var = $term -> readline( $question -> { 'desc' } . ( $question -> { 'default' } ? ( '[' . $question -> { 'default' } . ']' ) : '' ) );

	unless( $temp_var )
	{
		if( $question -> { 'default' } )
		{
			$temp_var = $question -> { 'default' };
		}
	}

	if( $question -> { 'oblig' } )
	{
		unless( $temp_var )
		{
			redo KSxcfevU;
		}
	}

	$data{ $question -> { 'key' } } = $temp_var;
	$qno ++;
}

print "\n\n",
      'Okay.',
      "\n",
      'I am ready to apply your settings now.',
      "\n",
      'Type "ok" to continue, anything other - quit.',
      "\n\n";

if( $term -> readline( '>' ) eq 'ok' )
{
	$data{ '%WENDY_LIB_DIRECTORY%' } = File::Spec -> catdir( $data{ '%WENDY_INSTALLATION_DIRECTORY%' }, 'lib' );
	$data{ '%DEFAULT_HOST_PACKAGE%' } = &form_address( $data{ '%DEFAULT_HOST%' } );
	&patch_files( %data );

	my $dir = getcwd();
	chdir 'wendy/var/hosts';
	rename( '%DEFAULT_HOST%', $data{ '%DEFAULT_HOST%' } ) or die 'Cant create default host directory: ' . $!;
	chdir $dir;

	touch( $configflag );

	print "\nAll done. See README file for further instuctions.\n";


} else
{
	print "\n" . "User quit. Nothing made" . "\n";
}

################################################################################

sub patch_files
{
	my %args = @_;

	my @varfiles = qw( wendy/lib/Wendy/Config.pm
			   wendy/misc/wendy-httpd.conf
			   wendy/misc/wendyinit.sql
			   wendy/misc/startup.pl
                           wendy/var/hosts/%DEFAULT_HOST%/lib/admin.pl );

	foreach my $file ( @varfiles )
	{

		if( -f $file
		    and
		    -R $file
		    and
		    -W $file )
		{

			print "patching " . $file . " ... ";

			&patch_file( $file,
				     %args );
			print " ok\n";

		} else
		{
			print "ERROR: file " .
			      $file . 
			      " not exists or not readable, or not writable!\n";
			return 1;
		}
	}

	return 0;
}

sub patch_file
{
	my $file = shift;
	my %args = @_;

	my $tfh = undef;


	if( open( $tfh, '<', $file ) )
	{
		my $patched_data = '';

		while( my $line = <$tfh> )
		{
			foreach my $from ( keys %args )
			{
				my $to = $args{ $from };
				$line =~ s/\Q$from\E/$to/g;
			}
			
			$patched_data .= $line;
		}
		
		close( $tfh );
		unless( &save_data_in_file_atomic( $patched_data, $file ) )
		{
			print "file ", $file, " patching error ", $!;
			die;
		}

	} else
	{
		print "could not read file ", $file, ": ", $!;
		die;
	}
	return 0;
}
