use strict;

package mod_captcha;

use Wendy::Templates;
use Wendy::Hosts;
use Wendy::Db;
use Wendy::Util;

use URI;

my $mybaseurl = "";
my $myid = "";
my $myhost = 0;

sub admin
{
	my $WOBJ = shift;
	my $ohtml = "";
        my $cgi = $WOBJ -> { "CGI" };
	
        $myhost = $cgi -> param( "host" );
        $myid   = $cgi -> param( "module" );
        $mybaseurl = '/admin/?action=modules&sub=invokeadm&host=' .
                     $myhost .
                     '&module=' .
                     $myid;

	$ohtml .= '[&nbsp;<a href="' .
	          $mybaseurl .
		  '">refresh</a>&nbsp;]';
	my $hosts = &all_hosts();
	my $test_url = '';

	{
		my $test_uri = new URI;
		$test_uri -> scheme( 'http' );
		$test_uri -> host( $hosts -> { $myhost } -> { 'host' } );
		$test_uri -> path( '/mod/captcha/test/' );
		$test_url = $test_uri -> as_string();
	}

	$ohtml .= '&nbsp'x3;
	$ohtml .= '[&nbsp;<a target="_blank" href="' .
	          $test_url .
		  '">test</a>&nbsp;]';

	return $ohtml;
}

1;

