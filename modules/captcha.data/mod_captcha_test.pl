use strict;

package mod_captcha_test;

use Wendy::Templates;
use Wendy::Modules::Captcha;

sub wendy_handler
{
	my $WOBJ = shift;


	my ( $public,
	     $userguess ) = map { scalar $WOBJ -> { 'CGI' } -> param( $_ ) } ( 'public',
									       'userguess' );
									      

	my $outcome = '';

	if( $public and $userguess )
	{
		if( &check_captcha( $public,
				    $userguess ) )
		{
			$outcome .= '<font color="green"><b>Welcome, human soul!</b></font><P>';
		} else
		{
			$outcome .= '<font color="red"><b>Wrong, stupid robot!</b></font><p>';
		}
	}

	my $cap = Wendy::Modules::Captcha -> new();
	$cap -> set_text();

	&add_replace( 'VALIDATION_RESULTS' => $outcome,
		      'PUBLICSEC' => $cap -> get_public(),
		      'CAPSRC' => $cap -> captcha_uri() );

	my $proc = &template_process( 'mod_captcha_test' );
	$proc -> { "nocache" } = 1;

	return $proc;
}

1;

