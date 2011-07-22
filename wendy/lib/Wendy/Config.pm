#!/usr/bin/perl

use strict;

package Wendy::Config;

use Moose;
use File::Spec;

has 'DBNAME' => ( is => 'ro', isa => 'Str', default => '%DATABASE_NAME%' );
has 'DBUSER' => ( is => 'ro', isa => 'Str', default => '%DATABASE_USER%' );
has 'DBPASSWORD' => ( is => 'ro', isa => 'Str', default => '%DATABASE_PASSWORD%' );
has 'DBPORT' => ( is => 'ro', isa => 'Int', default => int( '%DATABASE_PORT%' ) );
has 'DBHOST' => ( is => 'ro', isa => 'ArrayRef[Str]', default => [ '%DATABASE_HOST%' ] );


# if you want to read from one hosts, and write to another
# otherwise set to false

has 'WDBHOST' => ( is => 'ro', isa => 'Str', default => '' ); 

has 'DEFHOST' => ( is => 'ro', isa => 'Str', default => '%DEFAULT_HOST%' );
has 'MYPATH' => ( is => 'ro', isa => 'Str', default => '%WENDY_INSTALLATION_DIRECTORY%' );

has 'VARPATH' => ( is => 'ro', isa => 'Str', default => File::Spec -> catdir( '%WENDY_INSTALLATION_DIRECTORY%', 'var' ) );

has 'MEMCACHED' => ( is => 'ro', isa => 'Bool', default => 0 );

# may put here several records
has 'MC_SERVERS' => ( is => 'ro', isa => 'ArrayRef[Str]', default => [ '127.0.0.1:11211' ] ); 
has 'THRHOLD' => ( is => 'ro', isa => 'Int', default => 10000 );
has 'NORHASH' => ( is => 'ro', isa => 'Bool', default => 0 );
has 'NOCACHE' => ( is => 'ro', isa => 'Bool', default => 0 );
has 'VERSION' => ( is => 'ro', isa => 'Str', default => '0.0.2011072201' );

no Moose;

42;
