use strict;

use File::Spec;
use Wendy::Return;

package Wendy::Template;

use Moose;

has 'host' => ( is => 'rw', isa => 'Wendy::Host' );
has 'path' => ( is => 'rw', isa => 'Wendy::Path' );
has 'data' => ( is => 'rw', isa => 'Str' );
has 'replaces' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'tt' => ( is => 'rw', isa => 'Template' );
has 'tt_options' => ( is => 'rw', isa => 'HashRef' );
has 'lng' => ( is => 'rw', isa => 'Wendy::Lng' );

sub BUILD
{
	my $self = shift;

	unless( $self -> tt() )
	{
		my $conf = Wendy::Config -> cached();

		my $all_hosts_path = File::Spec -> catdir( $conf -> VARPATH(), 'hosts' );
		my $path = File::Spec -> catdir( $allhostspath, $self -> host() -> name(), 'tpl' );


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

	my $tplname = undef;

	if( my $t = $self -> data() )
	{
		# we process raw data
		$tplname = \$t;

	} elsif( my $p = $self -> path() )
	{
		# we process template in hosts directory
		$tplname = $p -> path();

	} else
	{
		# we politely die
		die 'do not know how to process this template';
	}

        my $template = $self -> tt();

        my $output = '';

        unless( $template -> process( $tplname, $self -> replaces(), \$output ) )
        {
                $output = $template -> error();
        }

	my $rv = Wendy::Return -> new( data => $output );

        return $rv;
}

sub load_replaces
{
	my $self = shift;


	my %args = @_;


	unless( $self -> lng() )
	{
		die 'language not set';
	}

	# to be continued ...
	# later


}

42;
