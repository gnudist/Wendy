use strict;

use File::Spec;
use Wendy::Return;
use Wendy::Util::Db;

use Template;

package Wendy::Template;

use Moose;

has 'host' => ( is => 'rw', isa => 'Wendy::Host' );
has 'path' => ( is => 'rw', isa => 'Wendy::Path' );
has 'data' => ( is => 'rw', isa => 'Str' );
has 'replaces' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'tt' => ( is => 'rw', isa => 'Template' );
has 'tt_options' => ( is => 'rw', isa => 'HashRef' );
has 'lng' => ( is => 'rw', isa => 'Wendy::Lng' );

use Wendy::Util::File 'slurp';

sub BUILD
{
	my $self = shift;

	unless( $self -> tt() )
	{
		my $conf = Wendy::Config -> cached();

		my $all_hosts_path = File::Spec -> catdir( $conf -> VARPATH(), 'hosts' );
		my $path = File::Spec -> catdir( $all_hosts_path, $self -> host() -> name(), 'tpl' );


		my $config = { INCLUDE_PATH => [ $path,
						 $all_hosts_path ],
			       POST_CHOMP   => 1,
			       EVAL_PERL    => 1 };


		if( my $t = $self -> tt_options() )
		{
			while( my ( $k, $v ) = each %{ $t } )
			{
				$config -> { $k } = $v;
			}
		}
		
		my $template = Template -> new( $config );
		$self -> tt( $template );

	}
}


sub execute
{

	my $self = shift;

	my $process_data = undef;

        my $template = $self -> tt();

	if( my $t = $self -> data() )
	{
		# we process raw data
		$process_data = $t;

	} elsif( my $p = $self -> path() )
	{
		# we process template in hosts directory
		my $tplname = $p -> path();

		my $tt_conf = $template -> context() -> config();

P3LxSTU7ccNCD61i:
		foreach my $path ( @{ $tt_conf -> { 'INCLUDE_PATH' } } )
		{
			if( -f ( my $t = File::Spec -> catfile( $path, $tplname ) ) )
			{
				$process_data = &slurp( $t );
				last P3LxSTU7ccNCD61i;
			}
		}
	}

	unless( $process_data )
	{
		# we politely die
		die '(no data found) do not know how to process this template';
	}

        my $output = '';

	$process_data = $self -> pre_process( $process_data );

        unless( $template -> process( \$process_data, $self -> replaces(), \$output ) )
        {
                $output = $template -> error();
        }

	my $rv = Wendy::Return -> new( $self -> post_process( $output ) );

        return $rv;
}

sub pre_process
{
	my $self = shift;

	my $data = shift;

	my $functional_regexp = qr/^\!(LOAD|COMMENT):(.+)$/;
	my $split_regexp = qr/[\x0d\x0a]+/;

	foreach my $line ( split( $split_regexp, $data ) )
	{

		if( $line =~ $functional_regexp )
		{
			my ( $kw, $arg ) = ( $1, $2 );

			if( $kw eq 'LOAD' )
			{
				# PROCESS LOAD KEYWORD
				1;
			}

			$data =~ s/$split_regexp?\Q$line\E$split_regexp?//g;
		}
	}

	return $data;

}

sub post_process
{
	my $self = shift;

	my $data = shift;

	my %rv = ();

	my $functional_regexp = qr/^\!(CTYPE):(.+)$/;
	my $split_regexp = qr/[\x0d\x0a]+/;

	foreach my $line ( split( $split_regexp, $data ) )
	{

		if( $line =~ $functional_regexp )
		{
			my ( $kw, $arg ) = ( $1, $2 );

			if( $kw eq 'CTYPE' )
			{
				$rv{ 'ctype' } = $arg;
			}

			$data =~ s/$split_regexp?\Q$line\E$split_regexp?//g;
		}
	}

	$rv{ 'data' } = $data;


	return %rv;

}

sub load_replaces
{
	my $self = shift;

	my %args = @_;

	my $lng = &extract_lng_id( $args{ 'Lng' } or $self -> lng() -> id() );
	my $host = &extract_host_id( $args{ 'Host' } or $self -> host() -> id() );
	my $addr = ( $args{ 'Address' } or $self -> path() -> path() );

	my %replaces = Wendy::Util::Db -> query_many( Table => 'wendy_macros',
						      Where => sprintf( "active=true AND lng=%d AND host=%d AND address=%s",
									$lng,
									$host,
									Wendy::Db -> quote( $addr ) ) );


	if( %replaces )
	{

		my %current_replaces = $self -> replaces();

		map { $current_replaces{ $_ -> { 'name' } } = $_ -> { 'body' } } values %replaces;
		$self -> replaces( \%current_replaces );
	}

}

sub extract_lng_id
{
	my $v = shift;

	if( $v =~ /^\d+$/ )
	{
		# this is numeric lng is
		return $v;
	}

	# this is lng like "ru" or "en"

	my $l = Wendy::Lng -> new( name => $v );
	return $l -> id();

}

sub extract_host_id
{
	my $v = shift;

	if( $v =~ /^\d+$/ )
	{
		# this is numeric host is
		return $v;
	}

	# this is host name

	my $h = Wendy::Host -> new( name => $v );

	return $h -> id();
}

42;
