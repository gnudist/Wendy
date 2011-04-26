use strict;

package %DEFAULT_HOST_PACKAGE%::admin;

use MIME::Base64;

use Wendy::Users;
use Wendy::Procs;
use Wendy::Hosts;
use Wendy::Config;
use Wendy::Util;
use Wendy::Templates;
use Wendy::Modules;
use Wendy::Db;


use XML::Quote;
use File::Spec;
use File::Util 'escape_filename';
use File::Touch;
use File::Temp;
use File::Basename;

use Fcntl ':flock';
use Digest::MD5 'md5_hex';
use URI;

sub wendy_handler
{
	my $WOBJ = shift;
	my $auth_ok = 0;

	&wdbconnect();

	my $outcome = { nocache => 1 };

	my $auth = $WOBJ -> { "REQREC" } -> headers_in -> { 'Authorization' };
	my $AUTHENTICATED_USER = undef;

	if( $auth )
	{
		my ( $username,
		     $password ) = split( /\Q:\E/, decode_base64( substr( $auth, 6 ) ) );

		$AUTHENTICATED_USER = &get_user( Login    => ( $username or '--------------------------------' ),
						 Password => ( $password or '--------------------------------' ) );

		if( scalar keys %$AUTHENTICATED_USER )
		{
			$auth_ok = 1;
			$WOBJ -> { "REQREC" } -> user( $username );
		} else
		{
			sleep( 5 );
		}
	}
		
	$WOBJ -> { "USER" } = $AUTHENTICATED_USER;

	unless( $auth_ok )
	{
		$outcome -> { "code" } = 401;
		$outcome -> { "msg"  } = "Authorization required.";
		$outcome -> { "data" } = "Authorization required.";

		$outcome -> { "headers" } = { 'WWW-Authenticate' => 'Basic realm="Wendy Site Editor"' };
		goto ADMINWORKFINISHED;
	}
###########################################################################
# AUTH OK:
###########################################################################

	my $cgi = $WOBJ -> { "CGI" };

	my $action = ( $cgi -> param( 'action' ) or 'default' );
	my $subaction = ( $cgi -> param( 'sub' ) or 'default' );

	&add_replace( 'ERROR_MESSAGE' => '',
		      'WENDY_VERSION' => $WENDY_VERSION );

	if( $action eq 'default' )
	{
		$WOBJ -> { "HPATH" } = "_admin_default";

		$outcome = &template_process( $WOBJ );

	} elsif( $action eq 'procs' )
	{
		my $working_area = "";

		if( $subaction eq 'new' )
		{
			&add_replace( 'USER_PROCNAME' => '',
				      'USER_PROCBODY' => '' );

			$working_area = 'INCLUDE:__int_admin_procs_new';
		} elsif( $subaction eq 'addnew' )
		{
			my $n_procname = $cgi -> param( 'procname' );
			my $n_procbody = $cgi -> param( 'procbody' );

			my $sql = sprintf( "INSERT INTO perlproc (name,body) VALUES (%s,%s)",
					   &dbquote( $n_procname ),
					   &dbquote( $n_procbody ) );

			eval { &wdbdo( $sql ) };

			if( $@ )
			{
				&add_replace( 'ERROR_MESSAGE' => xml_quote( $@ ),
					      'USER_PROCNAME' => xml_quote( $n_procname ),
					      'USER_PROCBODY' => xml_quote( $n_procbody ) );
				
				$working_area = 'INCLUDE:__int_admin_procs_new';
				
			} else
			{
				&add_replace( 'ERROR_MESSAGE' => "OK" );
			}



		} elsif( $subaction eq 'update' )
		{
			my $n_procname = $cgi -> param( 'procname' );
			my $n_procbody = $cgi -> param( 'procbody' );
			my $id = int( $cgi -> param( 'id' ) );


			my $sql = sprintf( "UPDATE perlproc SET name=%s, body=%s WHERE id=%s",
					   &dbquote( $n_procname ),
					   &dbquote( $n_procbody ),
					   &dbquote( $id ) );

			eval{ &wdbdo( $sql ) };

			if( $@ )
			{
				&add_replace( 'ERROR_MESSAGE' => xml_quote( $@ ),
					      'USER_PROCNAME' => xml_quote( $n_procname ),
					      'USER_PROCBODY' => xml_quote( $n_procbody ),
					      'PROCID'        => $id );
				
				$working_area = 'INCLUDE:__int_admin_procs_edit';
			} else
			{
				&add_replace( 'ERROR_MESSAGE' => "Update successful." );
			}

		} elsif( $subaction eq 'open' )
		{
			my $id = int( $cgi -> param( "id" ) );

			my $e_proc = &get_proc( Id => $id );


			&add_replace( 'USER_PROCNAME' => xml_quote( $e_proc -> { $id } -> { "name" } ),
				      'USER_PROCBODY' => xml_quote( $e_proc -> { $id } -> { "body" } ),
				      'PROCID'        => $id );
			
			$working_area = 'INCLUDE:__int_admin_procs_edit';
			
		} elsif( $subaction eq 'kill' )
		{
			my $id = int( $cgi -> param( "id" ) );
			
			my $sql = sprintf( "DELETE FROM perlproc WHERE id=%s",
					   &dbquote( $id ) );

			eval{ &wdbdo( $sql ) };

			if( $@ )
			{
				&add_replace( 'ERROR_MESSAGE' => xml_quote( $@ ) );
			
			} else
			{
				&add_replace( 'ERROR_MESSAGE' => "Delete successful." );
			}
		

		} else
		{
			my $procs = &get_all_proc_names();

			$working_area .= '<ul>';
			foreach my $pid ( sort { $procs -> { $a } -> { "name" }
						 cmp
						 $procs -> { $b } -> { "name" } } keys %$procs )
			{
				$working_area .= '<li><a href="/admin/?action=procs&sub=open&id=' .
				                 $pid .
				                 '">' .
				                 $procs -> { $pid } -> { "name" } .
						 '</a> [ <a onClick="return confirm(&quot;Really delete ' .
						 $procs -> { $pid } -> { "name" } .
						 '?&quot;)" href="/admin/?action=procs&sub=kill&id=' .
						 $pid .
						 '">' .
						 'delete</a> ]';
			}
			$working_area .= '</ul>';

		}

		
		$WOBJ -> { "HPATH" } = "_admin_procs";
		&add_replace( 'WORKING_AREA' => $working_area );
		$outcome = &template_process( $WOBJ );

	} elsif( $action eq 'languages' )
	{
		my $working_area = '<table border="0">';

		my %languages = &meta_get_records( Table  => 'language',
						   Fields => [ 'id', 'lng', 'descr' ] );
		

		foreach my $lid ( sort { $languages{ $a } -> { "lng" }
					 cmp
					 $languages{ $b } -> { "lng" } } keys %languages )
		{
			$working_area .= sprintf( '<tr><td>%s</td><td>%s</td></tr>',
						  $languages{ $lid } -> { "lng" },
						  $languages{ $lid } -> { "descr" } );
						  
		}

		$working_area .= '</table>';

		$WOBJ -> { "HPATH" } = "_admin_languages";
		&add_replace( 'WORKING_AREA' => $working_area );
		$outcome = &template_process( $WOBJ );

	} elsif( $action eq 'hosts' )
	{
		my $working_area = '';
		my $hosts = &all_hosts();
		my $host = int( $cgi -> param( 'host' ) );

		if( $subaction eq 'new' )
		{
			my ( $newhname,
			     $nolookup,
			     $errmsg,
			     $error ) = ( escape_filename( scalar $cgi -> param( 'name' ) ),
					  scalar $cgi -> param( 'nolook' ),
					  '',
					  0 );

			if( $newhname ) # do create host directory, subdirs, and empty root template
			{
				unless( $nolookup )
				{
					use Socket;
					my @rv = gethostbyname( $newhname );

					unless( scalar @rv )
					{
						$error = 1;
					}
				}

				if( $error )
				{
					$errmsg = 'DNS lookup failed for "' . $newhname . '" host';
				}

				unless( $error )
				{
					my $newdir = File::Spec -> catdir( CONF_VARPATH, 'hosts', $newhname  );
					
					unless( -d $newdir )
					{
						mkdir( $newdir ) or $error = 1;

						if( $error )
						{
							$errmsg = 'Cant create directory ' . 
							          $newdir . 
								  ': ' .
								  $!;
						}
					}


					unless( $error )
					{
yETMrFq4W6x:
						foreach my $subdir ( 'tpl', 'lib', 'htdocs', 'cache', File::Spec -> catdir( 'htdocs', 'mod' ), File::Spec -> catdir( 'htdocs', 'upload' ) )
						{
							my $newsubdir = File::Spec -> catdir( $newdir, $subdir );
							
							unless( -d $newsubdir )
							{
								mkdir( $newsubdir ) or $error = 1;

								if( $error )
								{
									$errmsg = 'Cant create directory ' . 
									          $newsubdir . 
										  ': ' .
										  $!;
									last yETMrFq4W6x;

								} else
								{

									if( $subdir eq 'htdocs' )
									{
										touch( File::Spec -> catfile( $newsubdir, 'wendyaddr' ) );
									}
								}
							}
						}
					}

					unless( $error )
					{
						my $roottpl = File::Spec -> catfile( $newdir, 'tpl', 'root' );

						eval { touch( $roottpl ) };

						if( $@ )
						{
							$errmsg = "Cant create root template " .
							          $roottpl . 
								  ": " .
								  $!;
							$error = 1;
						}
					}

				}

				unless( $error )
				{
					my $sql = sprintf( "INSERT INTO host (host) VALUES (%s)", &dbquote( $newhname ) );
					my $rc = &wdbdo( $sql );
					unless( $rc )
					{
						$errmsg = &wdbgeterror();
						$error = 1;
					}
				}

				unless( $error )
				{
					my $sql = sprintf( "INSERT INTO hostlanguage (host) VALUES ((SELECT id FROM host WHERE host=%s))", &dbquote( $newhname ) );
					my $rc = &wdbdo( $sql );
					unless( $rc )
					{
						$errmsg = &wdbgeterror();
						$error = 1;
					}
				}
			}

			$working_area = 'INCLUDE:__int_admin_hosts_new';

			if( $newhname and ( $error == 0 ) )
			{
				$working_area = &__htmlokmsg( '<b>OK, created new host ' . $newhname . '</b>' );
			}


			&add_replace( 'NAMEVAL'       => $newhname,
				      'NOLOOKUPCHECK' => $nolookup,
				      'ERROR_MESSAGE' => $errmsg ); 


		} elsif( $subaction eq 'open' )
		{
			$working_area .= '<h2>' . $hosts -> { $host } -> { "host" } . '</h2>';

			my %host_languages = &get_host_languages( $host );
			my %languages = &meta_get_records( Table  => 'language',
							   Fields => [ 'id', 'lng', 'descr' ] );

			$working_area = 'INCLUDE:__int_admin_hosts_open';

			my $deflngsel = "";
			my $hlngtrs = "";

			foreach my $lid ( sort { $host_languages{ $a }
					         cmp
					         $host_languages{ $b } }  keys %host_languages )
			{

				$deflngsel .= '<OPTION value="' .
				              $lid . 
					      '" ' .
					      ( $lid == $hosts -> { $host } -> { "defaultlng" } ? 'SELECTED' : '' ) .
					      '>' .
					      $host_languages{ $lid } .
					      ', ' .
					      $languages{ $lid } -> { "descr" } .
					      '</OPTION>';

				$hlngtrs .= '<tr>' .
				            '<td>' .
					    $host_languages{ $lid } .
					    '</td>' .
					    '<td>' .
					    $languages{ $lid } -> { "descr" } .
					    '</td>' .
					    '<td>' .
					    ( $lid == $hosts -> { $host } -> { "defaultlng" } ? '&nbsp;' : '<input type="checkbox" name="dl_' . $lid .'" value="yes">' ) .
					    '</td></tr>';
				

			}
			
			my $nlopts = "";
CcJbhGz7BY:
			foreach my $lid ( sort { $languages{ $a } -> { "lng" }
						 cmp
						 $languages{ $b } -> { "lng" } } keys %languages )
			{
				
				next CcJbhGz7BY if defined $host_languages{ $lid };
				$nlopts .= '<OPTION VALUE="' .
				           $lid .
					   '">' .
					   $languages{ $lid } -> { "lng" } .
					   ', ' .
					   $languages{ $lid } -> { "descr" } .
					   '</OPTION>';
			}

			&add_replace( 'HOSTID'        => $host,
				      'OPENEDHOST'    => $hosts -> { $host } -> { "host" },
				      'DEFLNGSELECT'  => $deflngsel,
				      'NEWLANGS'      => $nlopts,
				      'HOSTSLANGSTRS' => $hlngtrs );


		} elsif( $subaction eq 'update' )
		{
			my ( $defaultlng,
			     $newlng,
			     $borrowfrom ) = map { int( scalar $cgi -> param( $_ ) ) } ( 'defaultlng',
											 'addnewl',
											 'borrowfrom' );

			my ( $error,
			     $errormsg ) = ( 0, '' );

			if( $defaultlng )
			{
				my $sql = sprintf( "UPDATE host SET defaultlng=%s WHERE id=%s",
						   &dbquote( $defaultlng ),
						   &dbquote( $host ) );
				unless( &wdbdo( $sql ) )
				{
					$error = 1;
					$errormsg = &wdbgeterror();
				}

			}

			unless( $error )
			{
				if( $newlng )
				{
					my $sql = sprintf( "INSERT INTO hostlanguage (host,lng) VALUES (%s,%s)",
							   &dbquote( $host ),
							   &dbquote( $newlng ) );
					unless( &wdbdo( $sql ) )
					{
						$error = 1;
						$errormsg = &wdbgeterror();
					}
				}
			}

			unless( $error )
			{
				if( $newlng and $borrowfrom )
				{
					my %macros = &meta_get_records( Table => 'macros',
									Where => sprintf( "host=%s AND lng=%s",
											  &dbquote( $host ),
											  &dbquote( $borrowfrom ) ) );

					foreach my $mid ( keys %macros )
					{
						my $sql = sprintf( "INSERT INTO macros (name,body,istext,host,address,lng) VALUES(%s,%s,%s,%s,%s,%s)",
								   map { scalar &dbquote( $_ ) } ( $macros{ $mid } -> { "name" },
												   $macros{ $mid } -> { "body" },
												   $macros{ $mid } -> { "istext" },
												   $macros{ $mid } -> { "host" },
												   $macros{ $mid } -> { "address" },
												   $newlng ) );
						&wdbdo( $sql );
						# Errors ignored.
					}
				}
			}

			unless( $error )
			{
				my %host_languages = &get_host_languages( $host );

egM3G0VXhj:
				foreach my $lid ( keys %host_languages )
				{
					next egM3G0VXhj if $lid == $hosts -> { $host } -> { "defaultlng" };

					if( $cgi -> param( 'dl_' . $lid ) )
					{
						my $sql = sprintf( "DELETE FROM macros WHERE host=%s AND lng=%s",
								   &dbquote( $host ),
								   &dbquote( $lid ) );
						unless( &wdbdo( $sql ) )
						{
							$error = 1;
							$errormsg = &wdbgeterror();
							last egM3G0VXhj;
						}

						unless( $error )
						{
							my $sql = sprintf( "DELETE FROM hostlanguage WHERE host=%s AND lng=%s",
									   &dbquote( $host ),
									   &dbquote( $lid ) );

							unless( &wdbdo( $sql ) )
							{
								$error = 1;
								$errormsg = &wdbgeterror();
								last egM3G0VXhj;
							}
						}
					}

				}

			}

			

			if( $error )
			{
				&add_replace( 'ERROR_MESSAGE' => $errormsg );
			} else
			{
				$working_area = &__htmlokmsg( '<b>' .
				                'OK!' .
						'</b>' ) .
						' [ <a href="/admin/?action=hosts&sub=open&host=' .
						$host . 
						'">open host</a> ]';

			}

		}
		elsif( $subaction eq 'aliases' )
		{
			use Wendy::Hosts 'get_aliases';

			my $aliases_html = '';
			my $error_message = '';

			my $inv = $cgi -> param( 'inv' );
			my $aliases_modified = 0;
			my %aliases = &get_aliases( Host => $host );
			

			if( $inv )
			{
				my $newalias = $cgi -> param( "newalias" );

				if( $newalias )
				{
					my $sql = sprintf( "INSERT INTO host_alias (host,alias) VALUES (%s,%s)",
							   &dbquote( $host ),
							   &dbquote( $newalias ) );

					if( &wdbdo( $sql ) )
					{
						$aliases_modified = 1;
					} else
					{
						$error_message .= &wdbgeterror();
					}
				}

				foreach my $aid ( keys %aliases )
				{
					if( scalar $cgi -> param( 'deletealias_' . $aid ) )
					{
						if( &wdbdo( sprintf( "DELETE from host_alias WHERE id=%s",
								    &dbquote( $aid ) ) ) )
						{
							$aliases_modified = 1;
						} else
						{
							$error_message .= &wdbgeterror();
						}
					}
				}

			}


			if( $aliases_modified )
			{
				%aliases = &get_aliases( Host => $host );
			}

			foreach my $aid ( sort { $aliases{ $a } -> { "alias" }
					         cmp
						 $aliases{ $b } -> { "alias" } } keys %aliases )
			{
				$aliases_html .= '<tr>' .
				                 '<td>' .
						 $aliases{ $aid } -> { "alias" } .
						 '</td>' .
						 '<td>' .
						 '<input type="checkbox" name="deletealias_' .
						 $aid .
						 '" value="true">' .
						 '</td>' .
						 '</tr>';
			}

			&add_replace( 'HOSTNAME'      => $hosts -> { $host } -> { "host" },
				      'HOST_ID'       => $host,
				      'ERROR_MESSAGE' => $error_message,
				      'ALIASES_ROWS'  => $aliases_html );
			
			my $t_proc = &template_process( '__int_admin_hosts_aliases' );
			$t_proc -> { 'nocache' } = 1;
			return $t_proc;

		}
		elsif( $subaction eq 'delete' ) # delete is done only in DB, no files on disk deleted to avoid harm
		{
			my $sql = sprintf( "DELETE FROM macros WHERE host=%s", &dbquote( $host ) );
			my ( $error, $errormsg ) = ( 0, '' );

			if( $hosts -> { $host } -> { "host" } eq CONF_DEFHOST )
			{
				$errormsg = 'Cant delete default host.';
				$error = 1;
			}


			unless( &wdbdo( $sql ) )
			{
				$error = 1;
				$errormsg = &wdbgeterror();
			}

			unless( $error )
			{
				my $sql = sprintf( "DELETE FROM hostlanguage WHERE host=%s", &dbquote( $host ) );

				unless( &wdbdo( $sql ) )
				{
					$error = 1;
					$errormsg = &wdbgeterror();
				}
			}

			unless( $error )
			{
				my $sql = sprintf( "DELETE FROM host_alias WHERE host=%s", &dbquote( $host ) );

				unless( &wdbdo( $sql ) )
				{
					$error = 1;
					$errormsg = &wdbgeterror();
				}
			}

			unless( $error )
			{
				my $sql = sprintf( "DELETE FROM host WHERE id=%s", &dbquote( $host ) );

				unless( &wdbdo( $sql ) )
				{
					$error = 1;
					$errormsg = &wdbgeterror();
				}
			}


			
			if( $error )
			{
				$working_area = '';
				&add_replace( 'ERROR_MESSAGE', $errormsg );
			} else
			{
				$working_area = &__htmlokmsg( '<b>Deleted ' .
				                $hosts -> { $host } -> { "host" } .
						'</b>' );
			}


		} else
		{
			$working_area .= '<ul>';
			foreach my $hid ( sort { $hosts -> { $a } -> { "host" }
					         cmp
					         $hosts -> { $b } -> { "host" } } keys %$hosts )
			{
				$working_area .= '<li>' .
				                 '<a href="/admin/?action=hosts&sub=open&host=' .
						 $hid .
						 '">' .
				                 $hosts -> { $hid } -> { "host" } .
						 '</a>' .
						 '&nbsp;' .
						 '[ <a target="haliases_' .
						 $hid .
						 '" href="javascript:void(0)" onClick="openHostAliasesWindow(' .
						 $hid .
						 ')">aliases</a> ]' .
						 ( $hosts -> { $hid } -> { "host" } eq CONF_DEFHOST ? ' <a title="Default host.">*</a>' : ' [ <a onClick="return confirm(\'Really delete host ' . $hosts -> { $hid } -> { "host" } .'? All macros belonging to this host will be DELETED also!\')" href="/admin/?action=hosts&sub=delete&host=' . $hid . '">delete</a> ]' ) .
						 '</li>';

			}
			$working_area .= '</ul>';
		}

		$WOBJ -> { "HPATH" } = "_admin_hosts";
		&add_replace( 'WORKING_AREA' => $working_area );
		$outcome = &template_process( $WOBJ );

	} elsif( $action eq 'templates' )
	{
		my $working_area = "";
		my $hosts = &all_hosts();
		my $filterval = $cgi -> param( 'filter' );
		my $host = int( $cgi -> param( 'host' ) );
		my $name = escape_filename( $cgi -> param( 'name' ) );

		if( $subaction eq 'open' )
		{
			$working_area = 'INCLUDE:__int_admin_templates_edit';

			my $editmode = $cgi -> param( 'mode' );
			if( $editmode eq 'fancy' )
			{
				$working_area = 'INCLUDE:__int_admin_templates_edit_fancy';
			}

			my $tplfile = File::Spec -> catfile( CONF_VARPATH, 'hosts', $hosts -> { $host } -> { "host" }, 'tpl', $name );

			my $tfh = undef;
			my $tplcontents = "";

			if( open( $tfh, '<', $tplfile ) )
			{
				$tplcontents = xml_quote( join( '', <$tfh> ) );
				close( $tfh );
			} else
			{
				$tplcontents = "ERROR opening " .
				               $tplfile . 
					       ": " .
					       $!;
			}

			&add_replace( 'TEMPLATE_NAME'     => xml_quote( $name ),
				      'HOST_ID'           => $host,
				      'TEMPLATE_CONTENTS' => $tplcontents );

		} elsif( $subaction eq 'save' )
		{

			my $tplfile = File::Spec -> catfile( CONF_VARPATH, 'hosts', $hosts -> { $host } -> { "host" }, 'tpl', $name );
			my $tfh = undef;
			if( open( $tfh, '>', $tplfile ) )
			{
				if( flock( $tfh, LOCK_EX | LOCK_NB ) )
				{
					my $nc = $cgi -> param( 'contents' );
					print $tfh $nc;

					$working_area = &__htmlokmsg( '<b>OK, ' .
					                'saved ' .
							'<tt>' .
							$name .
							'</tt>' .
							' for host ' .
							$hosts -> { $host } -> { "host" } .
							'</b>' ) . '<p>';


				} else
				{
					$working_area = &__htmlerrmsg( 'CANT LOCK FILE ' .
					                $tplfile . 
							': ' .
							$! );
				}

				close $tfh;
			} else
			{
				$working_area = &__htmlerrmsg( 'CANT OPEN FILE ' .
				                $tplfile . 
						': ' .
						$! );
			}

			$working_area .= ' [ <a href="javascript:history.back()">Back</a> ] ';

		} elsif( $subaction eq 'listem' )
		{
			my $showservice = $cgi -> param( 'wservice' );

			if( $host )
			{
				map { delete $hosts -> { $_ } unless $_ == $host } keys %$hosts;
			}

			foreach my $hid ( keys %$hosts )
			{
				$working_area .= '<h2>' . $hosts -> { $hid } -> { "host" } . '</h2>';
				
				my $tplstore = File::Spec -> catdir( CONF_VARPATH, 'hosts', $hosts -> { $hid } -> { "host" }, 'tpl'  );

				my $tpldirfh = undef;

				if( opendir( $tpldirfh, $tplstore ) )
				{
					
					$working_area .= '<ul>';
aSzEzKgwCv:
					while( my $direntry = readdir( $tpldirfh ) )
					{
						next aSzEzKgwCv if index( $direntry, '.' ) == 0;
						if( $filterval )
						{
							next aSzEzKgwCv if index( $direntry, $filterval ) == -1;
						}
						unless( $showservice )
						{
							next aSzEzKgwCv unless index( $direntry, '_' );
						}

						my $direntry_q = xml_quote( $direntry );
						$working_area .= '<li>' . 
                                                                 '<a href="/admin/?action=templates&sub=open&name=' .
								 $direntry_q .
								 '&host=' .
								 $hid .
								 '">' .
								 $direntry_q .
								 '</a>' .
								 ' [ ' .
								 '<a onClick="return confirm(&quot;Delete template ' .
								 $direntry_q .
								 ' for host ' .
								 $hosts -> { $hid } -> { "host" } .
								 '?&quot;)" ' .
								 'href="/admin/?action=templates&sub=delete&name=' .
								 $direntry_q .
								 '&host=' .
								 $hid .
								 '">delete</a> ]';

					}
					$working_area .= '</ul>';

					closedir( $tpldirfh );
				} else
				{
					$working_area .= '<pre>' .
					                 'Error opening directory '.
							 $tplstore .
							 ': ' .
							 $! .
							 '</pre>';
				}

				


			}
			$working_area .= '<p>';


		} elsif( $subaction eq 'delete' )
		{
			my $tplfile = File::Spec -> catfile( CONF_VARPATH, 'hosts', $hosts -> { $host } -> { "host" }, 'tpl', $name );

			if( unlink( $tplfile ) )
			{
				$working_area = &__htmlokmsg( '<b>OK, deleted <tt>' .
				                $name .
						'</tt> for ' .
						$hosts -> { $host } -> { "host" } .
						'</b>' );
			} else
			{
				$working_area = &__htmlerrmsg( '<b>ERROR deleting <tt>' .
				                $name .
						'</tt> for ' .
						$hosts -> { $host } -> { "host" } .
						': ' .
						$! .
						'</b>' );

			}
			$working_area .= '<p>';

		} elsif( ( $subaction eq 'new' )
			 or
			 ( $subaction eq 'newp' ) )
		{
			$working_area = 'INCLUDE:__int_admin_templates_new';

			if( $subaction eq 'newp' )
			{
				$working_area = 'INCLUDE:__int_admin_templates_newp';
			}


			my $hosts_options = "";
			foreach my $hid ( sort {
				
				$hosts -> { $a } -> { "host" }
				cmp
				$hosts -> { $b } -> { "host" }

			                       } keys %$hosts )
			{
				$hosts_options .= '<OPTION value="' .
				                  $hid .
						  '" ' .
						  ( $hosts -> { $hid } -> { "host" } eq CONF_DEFHOST ? 'SELECTED' : '' ) .
						  '>' .
						  $hosts -> { $hid } -> { "host" } .
						  '</OPTION>';

			}
			&add_replace( 'HOSTS_OPTIONS' => $hosts_options,
				      'NAMEVAL'       => $name );

		} elsif( $subaction eq 'create' )
		{
			if( exists $hosts -> { $host }
			    and
			    $name )
			{
				my $tplfile = File::Spec -> catfile( CONF_VARPATH, 'hosts', $hosts -> { $host } -> { "host" }, 'tpl', $name );

				if( -f $tplfile )
				{
					$working_area = &__htmlerrmsg( 'Template ' .
					                '<tt>' . 
							$name .
							'</tt> already exists for host ' .
							$hosts -> { $host } -> { "host" } .
					                '.' ) . '<p>';
				} else
				{
					eval { touch( $tplfile ) };

					if( $@ )
					{
						$working_area = &__htmlerrmsg( 'Error creating ' .
						                '<tt>' . 
								$name .
								'</tt> for host ' .
								$hosts -> { $host } -> { "host" } .
								': ' .
								$@ ) . '<p>';
					} else
					{
						$working_area = &__htmlokmsg( 'Created ' .
						                '<tt>' . 
								$name .
								'</tt> for host ' .
								$hosts -> { $host } -> { "host" } .
								'.' ) . ' [ <a href="/admin/?action=templates&sub=open&name=' .
								xml_quote( $name ) .
								'&host=' .
								$host .
								'">open it</a> ]<p>';
					}
				}


			} else
			{
				$working_area = &__htmlerrmsg( 'Bad host or no template name specified.' ) . '<p>';
			}
			
		} elsif( $subaction eq 'createp' )
		{
			my $namep = $cgi -> param( 'namep' );

			my @nameparts = grep { escape_filename( $_ ) } map { $_ =~ s/\s//g ; $_ }  split( /\Q\/\E/, $namep );
			my $tplpath = escape_filename( &form_address( join( '/', @nameparts ) ) );

			my $tplfile;

			my $error = 0;
			{ # first, create empty template
				$tplfile = File::Spec -> catfile( CONF_VARPATH, 'hosts', $hosts -> { $host } -> { "host" }, 'tpl', $tplpath );
				eval { touch( $tplfile ) };
				if( $@ )
				{
					$working_area = &__htmlerrmsg( 'Error creating ' .
					                '<tt>' . 
							$namep .
							'</tt> for host ' .
							$hosts -> { $host } -> { "host" } .
							': ' .
							$@ ) . '<p>';
					$error = 1;
				}
			}

			unless( $error )
			{ # now, create directory hierarchy
				
				use Cwd;
				
				my $cwd = getcwd();
				my $htdocs = File::Spec -> catdir( CONF_VARPATH, 'hosts', $hosts -> { $host } -> { "host" }, 'htdocs' );

				chdir( $htdocs ) or $error = 1;
				
				if( $error )
				{
					$working_area = &__htmlerrmsg( 'Cant CD to ' .
					                $htdocs ) .
							'<p>';
					unlink $tplfile if -s $tplfile == 0;
				} else
				{
eX4UmHpVsM:
					foreach my $dpart ( @nameparts )
					{
						
						unless( -d $dpart )
						{
							mkdir( $dpart ) or $error = 1;
						}

						if( $error )
						{
							$working_area = &__htmlerrmsg( 'Cant create directory in htdocs: ' .
							                $dpart .
									': ' .
									$! ) . '<p>';
							unlink $tplfile if -s $tplfile == 0;
							last eX4UmHpVsM;
						}

						chdir( $dpart );
					}
					touch( 'wendyaddr' );
				}

				chdir $cwd;
			}

			unless( $error )
			{
				my $nurlie = 'http://' .
				             $hosts -> { $host } -> { "host" } .
					     '/' .
					     join( '/', @nameparts ) .
					     '/';

				my $otpl_urlie = '/admin/?action=templates&sub=open&name=' .
				                 $tplpath .
						 '&host=' .
						 $host;

				$working_area .= &__htmlokmsg( '<b>' .
				                 'OK!<p>Page: <a href="' .
						 $nurlie .
						 '">' .
						 $nurlie .
						 '</a><br> New template:' .
						 '<a href="' .
						 $otpl_urlie .
						 '">' .
						 $tplpath .
						 '</a>' .
						 '</b>' ) . '<br><br>';
			}
			
		}
		else
		{

			my $hosts_options = "";
			foreach my $hid ( sort {
				
				$hosts -> { $a } -> { "host" }
				cmp
				$hosts -> { $b } -> { "host" }

			                       } keys %$hosts )
			{
				$hosts_options .= '<OPTION value="' .
				                  $hid .
						  '">' .
						  $hosts -> { $hid } -> { "host" } .
						  '</OPTION>';

			}
			&add_replace( 'HOSTS_OPTIONS' => $hosts_options );

			$working_area = 'INCLUDE:__int_admin_templates_filter';
		}

		$WOBJ -> { "HPATH" } = "_admin_templates";
		&add_replace( 'WORKING_AREA' => $working_area,
			      'FILTERVAL' => $filterval );
		$outcome = &template_process( $WOBJ );

	} elsif( $action eq 'users' )
	{ 
		my $working_area = "";
		my $error_message = "";
		my ( $nulogin, $nupass, $id ) = map { scalar $cgi -> param( $_ ) } ( 'login', 'password', 'id' );

		$WOBJ -> { "HPATH" } = "_admin_users";

		if( $subaction eq 'open' )
		{
			my $user = &get_user( Id => $id );

			if( scalar keys %$user )
			{
				$nulogin = $user -> { "login" };
				&add_replace( 'PWVAL' => '',
					      'USERID' => $id );
			} else
			{
				$error_message = "Wrong user ID.";
			}

			$working_area .= 'INCLUDE:__int_admin_users_open';
		} elsif( $subaction eq 'update' )
		{
			my $user = &get_user( Id => $id );

		
			if( scalar keys %$user )
			{
				if( ( $user -> { "login" } eq 'root' ) and ( $AUTHENTICATED_USER -> { "login" } ne 'root' ) )
				{
					$error_message = "You cant update root user.";
				} else
				{
					my $sql = "UPDATE weuser SET password=%s WHERE id=%s";

					if( $nupass )
					{

						$sql = sprintf( $sql,
								&dbquote( $nupass ),
								&dbquote( $id ) );
						if( &wdbdo( $sql ) )
						{
							$working_area = &__htmlokmsg( '<b>OK, updated user ' .
							                $user -> { "login" } .
									'</b>' );
						} else
						{
							$error_message = &wdbgeterror();
						}


					} else
					{
						$error_message = 'Password not changed.';
					}
					
				}
			} else
			{
				$error_message = "Wrong user ID.";
			}



		} elsif( $subaction eq 'new' )
		{
			$working_area .= 'INCLUDE:__int_admin_users_new';

		} elsif( $subaction eq 'delete' )
		{
			my $user = &get_user( Id => $id );

			if( scalar keys %$user )
			{
				if( $user -> { "login" } eq $AUTHENTICATED_USER -> { "login" } )
				{
					$error_message = "Cant delete self.";
				} elsif( $user -> { "login" } eq 'root' )
				{
					$error_message = "Cant delete root user.";
				} else
				{
					my $sql = sprintf( "DELETE FROM weuser WHERE id=%s",
							   &dbquote( $id ) );

					if( &wdbdo( $sql ) )
					{
						$working_area = &__htmlokmsg( '<b>OK, deleted ' .
						                $user -> { "login" } .
								'</b>' );
					} else
					{
						$error_message = &wdbgeterror();
					}

				}

			} else
			{
				$error_message = 'User not found.';
			}



		} elsif( $subaction eq 'create' )
		{ 

			if( $nulogin )
			{
				
				my $sql = sprintf( "INSERT INTO weuser (login,password) VALUES (%s,%s)",
						   &dbquote( $nulogin ),
						   &dbquote( $nupass ) );
				
				if( &wdbdo( $sql ) )
				{
					$working_area = &__htmlokmsg( '<b>OK, created new user ' . xml_quote( $nulogin ) . '</b>' );
					
				} else
				{
					$error_message = &wdbgeterror();
					$working_area = "";
				}
			} else
			{
				$error_message = 'No login.';
			}


		} else
		{

			$working_area .= '<table border="0" width="100%">' .
			                 '<tr bgcolor="pink">' .
					 '<td width="1%"> id </td>' .
					 '<td> login </td>' .
					 '<td width="2%"> action </td> </tr>';

			my %users = &meta_get_records( Table  => 'weuser',
						       Fields => [ 'id', 'login', 'flag' ] );

			foreach my $uid ( sort {
				                       $users{ $a } -> { "login" }
						       cmp
						       $users{ $b } -> { "login" } } keys %users )
			{
				$working_area .= '<tr onMouseOver="this.bgColor=\'lightblue\'" onMouseOut="this.bgColor=\'white\'">';
				$working_area .= '<td>';
				$working_area .= $uid;
				$working_area .= '</td>';
				
				$working_area .= '<td>' .
				                 '<a href="/admin/?action=users&sub=open&id=' .
						 $uid .
						 '">';
				$working_area .= xml_quote( $users{ $uid } -> { "login" } );
				$working_area .= '</a></td>';

				$working_area .= '<td>';
				$working_area .= '<a onClick="return confirm(\'Delete user ' .
                                                 xml_quote( $users{ $uid } -> { "login" } ) .
				                 '?\')" href="/admin/?action=users&sub=delete&id=' .
				                 $uid .
				                 '">x</a>';
				$working_area .= '</td>';


				$working_area .= '</tr>';
			}


			$working_area .= '</table>';

		}

		&add_replace( 'WORKING_AREA'  => $working_area,
			      'ERROR_MESSAGE' => $error_message,
			      'LOGINVAL'      => $nulogin );
		$outcome = &template_process( $WOBJ );

	} elsif( $action eq 'cache' )
	{
		my $working_area = 'INCLUDE:__int_admin_cache_purge';
		my $error_message = '';
		my $hosts = &all_hosts();
		if( $subaction eq 'purge' )
		{
			my $filter = $cgi -> param( "filter" );
			my $host = int( $cgi -> param( "host" ) );
			
			if( $host )
			{
				foreach my $hid ( keys %$hosts )
				{
					unless( $hid == $host )
					{
						delete $hosts -> { $hid };
					}
				}
			}

			my $delcounts = 0;
			my $errcounts = 0;
			my $skipcounts = 0;

			foreach my $hid ( keys %$hosts )
			{
				my $cachedir = File::Spec -> catdir( CONF_VARPATH, 'hosts', $hosts -> { $hid } -> { "host" }, 'cache'  );
				my $dh = undef;
				if( opendir( $dh, $cachedir ) )
				{
tfeCUzrtXj:
					while( my $dentry = readdir( $dh ) )
					{
						next tfeCUzrtXj unless index( $dentry, '.' );
						
						my $cfname = File::Spec -> catfile( $cachedir, $dentry );
						unless( -e $cfname )
						{
							$errcounts ++;
							next tfeCUzrtXj;
						}
						unless( -f $cfname )
						{
							$errcounts ++;
						}
						if( $filter )
						{
							if( index( $dentry, $filter ) == -1 )
							{
								$skipcounts ++;
								next tfeCUzrtXj;
							}
						}

						unlink( $cfname ) ? $delcounts ++ : $errcounts ++;
					}

					close( $dh );
				} else
				{
					$error_message = 'Cant open cache directory ' .
					                 $cachedir .
							 ': ' .
							 $!;
				}
			}

			$working_area = &__htmlokmsg( '<b>' .
			                'Done. Deleted: ' . 
					$delcounts .
					' Errors: ' .
					$errcounts .
					' Skipped: ' .
					$skipcounts .
					'</b>' );

		} else
		{
			
			my $hosts_options = "";
			
			foreach my $hid ( sort {
				
				$hosts -> { $a } -> { "host" }
				cmp
				$hosts -> { $b } -> { "host" }
				
			} keys %$hosts )
			{
				$hosts_options .= '<OPTION value="' .
				    $hid .
				    '" ' .
				    '>' .
				    $hosts -> { $hid } -> { "host" } .
				    '</OPTION>';
			}
			&add_replace( 'HOSTS_OPTIONS' => $hosts_options );

		}

		$WOBJ -> { "HPATH" } = "_admin_cache";
		&add_replace( 'WORKING_AREA' => $working_area,
			      'ERROR_MESSAGE' => $error_message );
		$outcome = &template_process( $WOBJ );


	} elsif( $action eq 'modules' )
	{
		my ( $working_area,
		     $error_message ) = ( '', '' );
		
		my $modulesdir = File::Spec -> catdir( CONF_VARPATH, 'modules' );
		my $hosts = &all_hosts();
		if( $subaction eq 'install' )
		{
			my $modulename = $cgi -> param( "module" );
			my $modfilename = File::Spec -> catfile( $modulesdir, escape_filename( $modulename ) . ".wpm" );
								 
			eval { require $modfilename };

			if( $@ )
			{
				$error_message = $@;
			} else
			{
				no strict 'refs';
				my $install_handler = $modulename . '::' . 'install';

				my $rv = undef;
				my $ihost = $cgi -> param( 'host' );
				my @ihosts = ( $ihost );

				unless( $ihost )
				{
					@ihosts = keys %$hosts;
					my %installed_hosts = &is_installed( $modulename );

					my @thosts = ();

					foreach my $iid ( keys %installed_hosts )
					{
						if( &in( $installed_hosts{ $iid } -> { 'host' },
							 @ihosts ) )
						{
							@ihosts = grep { $_ != $installed_hosts{ $iid } -> { 'host' } } @ihosts;
						}
					}
				}
				
SzKoVjmktJ:
				foreach my $ihost ( @ihosts )
				{
					eval { $rv = &{ $install_handler }( Host => $ihost ) };

					if( $@ )
					{
						$error_message .= $@;
						last SzKoVjmktJ;
					}

					if( $rv )
					{
						if( $rv -> [ 0 ] )
						{
							$error_message .= 'Install error: (' .
							                  $hosts -> { $ihost } -> { "host" } .
									  ') ' .
									  $rv -> [ 1 ];
						} else
						{
							$working_area .= '<p>' . &__htmlokmsg( '<b><pre>' .
							                 $hosts -> { $ihost } -> { "host" } .
									 ': ' .
									 'OK<p>' . $rv -> [ 1 ] . '</pre></b>' );

							
							&register_module( Host => $ihost,
									  Module => $modulename );

						}

					} else
					{
						$error_message .= '<p>Error: nothing returned from install handler!';
					}
				}

			}
			


		} elsif( $subaction eq 'uninstall' )
		{
			my $modulename = $cgi -> param( "module" );
			my $modfilename = File::Spec -> catfile( $modulesdir, escape_filename( $modulename ) . ".wpm" );
								 
			eval { require $modfilename };

			if( $@ )
			{
				$error_message = $@;
			} else
			{
				no strict 'refs';
				my $install_handler = $modulename . '::' . 'uninstall';

				my $rv = undef;
				my $ihost = $cgi -> param( 'host' );
				my @ihosts = ( $ihost );

				unless( $ihost )
				{
					@ihosts = ();
					my %installed_hosts = &is_installed( $modulename );
					foreach my $iid ( keys %installed_hosts )
					{
						push @ihosts, $installed_hosts{ $iid } -> { "host" };
					}
				}
zEOq9HXnWv:
				foreach my $ihost ( @ihosts )
				{
					eval { $rv = &{ $install_handler }( Host => $ihost ) };

					if( $@ )
					{
						$error_message .= $@;
						last zEOq9HXnWv;
					}

					if( $rv )
					{
						if( $rv -> [ 0 ] )
						{
							$error_message .= 'UnInstall error: (' .
							                  $hosts -> { $ihost } -> { "host" } .
									  ') ' .
									  $rv -> [ 1 ];
						} else
						{
							$working_area .= '<p>' . &__htmlokmsg( '<b><pre>' .
							                 $hosts -> { $ihost } -> { "host" } .
									 ': ' .
									 'OK<p> ' . $rv -> [ 1 ] . '</pre></b>' );

							
							&unregister_module( Host => $ihost,
									    Module => $modulename );

						}

					} else
					{
						$error_message .= '<p>Error: nothing returned from uninstall handler!';
					}

				}

			}
			
		} elsif( $subaction eq 'invokeadm' )
		{

			my $mid = $cgi -> param( 'module' );
			my %module = &installed_modules( Id => $mid );

			if( scalar keys %module )
			{
				my $module_name = $module{ $mid } -> { "name" };
				my $admin_handler_src = File::Spec -> catfile( CONF_VARPATH, 'modules', $module_name . '.data', 'admin.pl' );

				$working_area .= $admin_handler_src . '<br>';

				eval { require $admin_handler_src };
### TODO TODO
			
				if( $@ )
				{
					$working_area .= 'ERROR in admin handler: ' . $@;
				} else
				{
					no strict "refs";

					my $rv = eval { &{ 'mod_' . $module_name . '::admin' }( $WOBJ ) };

					if( $@ )
					{
						$working_area .= 'Run-time error in admin handler: ' . $@;
					} else
					{
						if( ref( $rv ) )
						{
							$outcome = $rv;
							goto ADMINWORKFINISHED;
						} else
						{
							$working_area = $rv;
						}
					}
				}



			} else
			{
				$working_area = "BAD MODULE";
			}


		} else
		{
			my $dh = undef;
			
			if( opendir( $dh, $modulesdir ) )
			{
				$working_area = 'INCLUDE:__int_admin_modules_list';
				
				
				my %installed_modules = &installed_modules();
				my $display_install_dialog_body = '';
				my $display_uninstall_dialog_body = '';
				my $reset_inner_body = '';
				my $modules_tds = '';
				
				my %installed_on_stats = ();
				
				
r54dhYfkP6:			
				while( my $dentry = readdir( $dh ) )
				{
					next r54dhYfkP6 unless index( $dentry, '.' );
					my $actual_file = File::Spec -> catfile( $modulesdir, $dentry );
					
					next r54dhYfkP6 unless -f $actual_file;
					next r54dhYfkP6 unless $dentry =~ /(\w+)\.wpm$/;
					
					my $modulename = $1;
					
					$modules_tds .= '<tr onMouseOver="this.bgColor=\'lightblue\'" onMouseOut="this.bgColor=\'white\'">';
					$modules_tds .= '<td>' .
					    $modulename .
					    '</td>';
					
					{
						no strict 'refs';
						my $minfo = '&nbsp;';
						my $minfo_method = $modulename . '::' . 'module_info';
						eval { require $actual_file };
						
						if( $@ )
						{
							$error_message .= '<p>Error requiring module ' .
							    $actual_file .
							    ': ' .
							    $@;
						} elsif( exists &{ $minfo_method } )
						{
							my %minfo = &{ $minfo_method }();
							$minfo = xml_quote( $minfo{ 'Description' } .
									    ' by ' .
									    $minfo{ 'Author' } );
							
						}
						
						
						$modules_tds .= '<td>' .
						    $minfo .
						    '</td>';
					}
					
					
					{
						my $installed_data = ' not installed ';
						my @hosts = ();
						foreach my $imid ( keys %installed_modules )
						{
							if( $installed_modules{ $imid } -> { "name" } eq $modulename )
							{
								push @hosts, $installed_modules{ $imid } -> { "host" };
								delete $installed_modules{ $imid };
							}
						}
						
						if( scalar @hosts )
						{
							$installed_data = "Installed on: ";
							$installed_data .= join( ', ', map { $hosts -> { $_ } -> { "host" } } @hosts );
						}
						$installed_on_stats{ $modulename } = \@hosts;
						
						
						$modules_tds .= '<td>' .
						    $installed_data .
						    '</td>';
					}
					
					{
						my $qmn = xml_quote( $modulename );
						my $reset_inner = '[&nbsp;<a onClick="return displayInstallDialog(\'' .
						    $qmn .
						    '\')" href="/admin/?action=modules&sub=install&module=' .
						    $qmn .
						    '">Install</a>&nbsp;]' .
						    '[&nbsp;<a onClick="return displayUninstallDialog(\'' .
						    $qmn .
						    '\')" href="/admin/?action=modules&sub=uninstall&module=' .
						    $qmn .
						    '">Uninstall</a>&nbsp;]';
						
						$modules_tds .= '<td><div id="actionsDivModule' . $qmn . '">' .
						    $reset_inner .
						    '</div></td>';
						
						
						my $inst_hosts_options = '';
						my $uninst_hosts_options = '';
						
						foreach my $hid ( sort { $hosts -> { $a } -> { "host" }
									 cmp 
									     $hosts -> { $b } -> { "host" } } @{ $installed_on_stats{ $modulename } } )
						{
							
							$uninst_hosts_options .= '<OPTION VALUE="' .
							    $hid .
							    '">' .
							    $hosts -> { $hid } -> { "host" } .
							    '</OPTION>';
							
						}
						
						my $uninst_inner = "";
						
						if( $uninst_hosts_options )
						{
							$uninst_inner = "<form method=\"POST\" action=\"/admin/\">" .
							    "<input type=\"hidden\" name=\"action\" value=\"modules\">" .
							    "<input type=\"hidden\" name=\"sub\" value=\"uninstall\">" .
							    "<input type=\"hidden\" name=\"module\" value=\"' + moduleName + '\">" .
							    "<table border=\"0\" width=\"100%\"><tr bgcolor=\"#3fa5f4\">" .
							    "<td colspan=\"2\">Un-Install&nbsp;module&nbsp;" .
							    $qmn . 
							    "</td></tr><tr bgcolor=\"cyan\"><td><select name=\"host\">" .
							    "<option value=\"0\"> Uninstall from all hosts </option>" .
							    $uninst_hosts_options .
							    "</select></td><td width=\"1%\"><input type=\"submit\" value=\" OK \">" .
							    "</td></tr></table></form>";
						} else
						{
							$uninst_inner = "This module is not installed to any host now.";
						}
						
						$uninst_inner .= '<center>[&nbsp;<a onClick="return resetModuleActions( &quot;' .
						    $qmn .
						    '&quot; )" ' .
						    'href="javascript:void(0)">Back</a>&nbsp;]</center>';
						
						foreach my $hid ( sort { $hosts -> { $a } -> { "host" }
									 cmp
									     $hosts -> { $b } -> { "host" } } keys %$hosts )
						{
							unless( &in( $hid, @{ $installed_on_stats{ $modulename } } ) )
							{
								$inst_hosts_options .= '<OPTION VALUE="' . $hid . '">' .
								    $hosts -> { $hid } -> { "host" } .
								    '</OPTION>';
							}
						}
						
						my $inner = "";
						
						if( $inst_hosts_options )
						{
							$inner = "<form method=\"POST\" action=\"/admin/\">" .
							    "<input type=\"hidden\" name=\"action\" value=\"modules\">" .
							    "<input type=\"hidden\" name=\"sub\" value=\"install\">" .
							    "<input type=\"hidden\" name=\"module\" value=\"' + moduleName + '\">" .
							    "<table border=\"0\" width=\"100%\"><tr bgcolor=\"#3fa5f4\">" .
							    "<td colspan=\"2\">Install&nbsp;module&nbsp;" .
							    $qmn . 
							    "</td></tr><tr bgcolor=\"cyan\"><td><select name=\"host\">" .
							    "<option value=\"0\"> Install to all hosts </option>" .
							    $inst_hosts_options .
							    "</select></td><td width=\"1%\"><input type=\"submit\" value=\" OK \">" .
							    "</td></tr></table></form>";
						} else
						{
							$inner = "This module is already installed to all available hosts.";
						}
						
						$inner .= '<center>[&nbsp;<a onClick="return resetModuleActions( &quot;' .
						    $qmn .
						    '&quot; )" ' .
						    'href="javascript:void(0)">Back</a>&nbsp;]</center>';
						
						
						$display_install_dialog_body .= "if( moduleName == '" .
						    $qmn .
						    "' ) { newInner='" .
						    $inner .
						    "'; }";
						
						
						$display_uninstall_dialog_body .= "if( moduleName == '" .
						    $qmn .
						    "' ) { newInner='" .
						    $uninst_inner .
						    "'; }";
						
						
						$reset_inner =~ s/\Q\'\E/&quot;/g;
						$reset_inner_body .= "if( moduleName == '" .
						    $qmn .
						    "' ) { newInner='" .
						    $reset_inner .
						    "'; }";
					}
					
					$modules_tds .= '</tr>';
					
					
					
				}
				
				&add_replace( 'MODULES_TDS'                   => $modules_tds,
					      'RESET_MODULE_ACTIONS_BODY'     => $reset_inner_body,
					      'DISPLAY_UNINSTALL_DIALOG_BODY' => $display_uninstall_dialog_body,
					      'DISPLAY_INSTALL_DIALOG_BODY'   => $display_install_dialog_body );
				
				
				closedir( $dh );
			} else
			{
				$error_message = "Cant open modules dir, " . $modulesdir . ': ' . $!;
			}


			{
				# look up modules for admin handlers
				my $ext_mod_adm_html = '';
				
				my $hosts = &all_hosts();
				
				foreach my $hid ( sort {
					
					$hosts -> { $a } -> { "host" }
					cmp
					    $hosts -> { $b } -> { "host" }
					
				} keys %$hosts )
				{
					$ext_mod_adm_html .= '<h3>' . $hosts -> { $hid } -> { "host" } . '</h3>';
					
					my %installed_modules = &installed_modules( Host => $hid );
					
					if( scalar keys %installed_modules )
					{
						$ext_mod_adm_html .= '<ul>';

						foreach my $mid ( sort { $installed_modules{ $a } -> { "name" }
									 cmp
									 $installed_modules{ $b } -> { "name" } } keys %installed_modules )
						{
							my $admin_handler_src = File::Spec -> catfile( CONF_VARPATH, 'modules', $installed_modules{ $mid } -> { "name" } . '.data', 'admin.pl' );

							
							$ext_mod_adm_html .= '<li>' . 
							    ( -f $admin_handler_src ? '<a href="/admin/?action=modules&sub=invokeadm&host=' .
							      $hid .
							      '&module=' .
							      $mid .
							      '">' : '' ) . 
							      $installed_modules{ $mid } -> { "name" } .
							      ( -f $admin_handler_src ? '</a>': '' ) .
							      '</li>';
						}
						$ext_mod_adm_html .= '</ul>';

					} else
					{
						$ext_mod_adm_html .= '<p>No modules installed for this host.';
					}
				}
				&add_replace( 'EXTERN_MODULES_ADMINS', $ext_mod_adm_html );
			}
		}

		$WOBJ -> { "HPATH" } = "_admin_modules";
		&add_replace( 'WORKING_AREA'  => $working_area,
			      'ERROR_MESSAGE' => $error_message );

		$outcome = &template_process( $WOBJ );


	} elsif( $action eq 'upload' )
	{
		my $working_area = '';
		my $hosts_options = "";
		my $hosts = &all_hosts();
			


		foreach my $hid ( sort {
			
			$hosts -> { $a } -> { "host" }
			cmp
			$hosts -> { $b } -> { "host" }
			
		} keys %$hosts )
		{
			$hosts_options .= '<OPTION value="' .
			                  $hid .
					  '" ' .
					  ( $hid == $WOBJ -> { "HOST" } -> { "id" } ? 'SELECTED' : '' ) .
					  '>' .
					  $hosts -> { $hid } -> { "host" } .
					  '</OPTION>';
		}


		$WOBJ -> { "HPATH" } = "_admin_files_upload";
		&add_replace( 'WORKING_AREA'  => $working_area,
			      'HOSTS_OPTIONS' => $hosts_options );
		$outcome = &template_process( $WOBJ );

	} elsif( $action eq 'files' )
	{
		my $working_area = "";
		my $chrootpath = File::Spec -> catdir( CONF_VARPATH, 'hosts' );
		my $location = $chrootpath;
		my $plocation     = "";
		my $error_message = "";
		my $uploaded_written_filename = "";
		my $showparent = 0;
		my $simple_mode = 0;
		my $hosts = &all_hosts();
		
		my $host_id = $WOBJ -> { "HOST" } -> { "id" };

		{
			my $ui_host = $cgi -> param( "host" );
			if( exists $hosts -> { $ui_host } )
			{
				$host_id = $ui_host;
			}
		}
		
 		{ # make new location safe

			my $goto = $cgi -> param( 'location' );

			if( $goto eq 'auto' )
			{
				$simple_mode = 1;
				
				my $base_location = File::Spec -> catdir( CONF_VARPATH, 'hosts', $hosts -> { $host_id } -> { "host" }, 'htdocs' );
				$location = File::Spec -> catdir( $base_location, 'upload' );
				
				unless( -d $location )
				{
					$location = $base_location;
				}
				
			} else
			{
				$goto = decode_base64( $goto );

				if( $goto )
				{
					$showparent = 1;
					$location = $goto;
				}
				
				my $rel_path = File::Spec -> abs2rel( $location, $chrootpath );
				my @rpa = grep { index( $_, '.' ) } File::Spec -> splitdir( $rel_path );
				
				$location = File::Spec -> canonpath( File::Spec -> catdir( $chrootpath, @rpa ) );
				pop @rpa;
				$plocation = File::Spec -> canonpath( File::Spec -> catdir( $chrootpath, @rpa ) );
				
				if( $location eq $chrootpath )
				{
					$showparent = 0;
				}
			}
			
 		}
		my $inputloc = encode_base64( $location, '' );

		if( $showparent )
		{

			$working_area .= '<a href="/admin/?action=files&location=' .
			                 encode_base64( $plocation, '' ) .
					 '"> Upper level </a><p>';

		}

		$WOBJ -> { "HPATH" } = "_admin_files";
		{
			my $cwd = getcwd();
			if( chdir( $location ) )
			{
				
				my $to_delete = escape_filename( decode_base64( $cgi -> param( 'delete' ) ) );
				if( $to_delete )
				{
					my $error = 0;

					if( -d $to_delete )
					{
						rmdir( $to_delete ) or $error = 1;
					} else
					{
						unlink( $to_delete ) or $error = 1;
					}

					if( $error )
					{
						$error_message = 'Error deleting ' . xml_quote( $to_delete ) . ': ' . $!;
					}

				}

				my $newdir = escape_filename( $cgi -> param( 'newdir' ) );
				if( $newdir )
				{
					my $error = 0;
					
					unless( mkdir( $newdir ) )
					{
						$error = 1;
						$error_message = 'Cant create directory ' . xml_quote( $newdir ) . ': ' . $!;
					}
				}

				my $newfile = $cgi -> upload( 'newfile' );
				
				if( $newfile )
				{
					my $filename = $newfile;
					
					if( $cgi -> param( 'asname' ) )
					{
						$filename = $cgi -> param( 'asname' );
					}

					$filename = sprintf( "%s", escape_filename( $filename ) );

					if( -e $filename )
					{

						$error_message .= 'Will not overwrite ' . xml_quote( $filename );
					} else
					{
						my $fh = undef;
						
						if( open( $fh, '>', $filename ) )
						{
							binmode( $fh );
							binmode( $newfile );
							my $buf = "";
							
							while( read( $newfile, $buf, 1024 ) )
							{
								print $fh $buf;
							}
							close( $fh );
						} else
						{
							$error_message .= 'Cant open ' . xml_quote( $filename ) . ': ' . $!;
						}
					}
					$uploaded_written_filename = $filename;
				}


				if( $simple_mode )
				{
					my $link_to_uploaded_file = URI -> new();

					$link_to_uploaded_file -> scheme( 'http' );
					$link_to_uploaded_file -> host( $hosts -> { $host_id } -> { "host" } );

					my $blocation = "";
					my $hpath = File::Spec -> catdir( $hosts -> { $host_id } -> { "host" }, 'htdocs' );

					$blocation = File::Spec -> catfile( substr( $location, index( $location, $hpath ) + length( $hpath ) ),
									    $uploaded_written_filename );

					$link_to_uploaded_file -> path( $blocation );

					$working_area = '<b>New file uploaded:<a target="_blank" href="' .
					                xml_quote( $link_to_uploaded_file -> canonical() -> as_string() ) .
					                 '">' .
							 $link_to_uploaded_file -> canonical() -> as_string() . '</a></b>';
					$WOBJ -> { "HPATH" } = "_admin_files_simple";
					goto SKIPDIRECTORYLISTING;
				}

				my $dirhandle = undef;
				
				if( opendir( $dirhandle, $location ) )
				{
					$working_area .= '<table border="0" width="100%">';
kvLO23oqzz:
					while( my $dentry = readdir( $dirhandle ) )
					{
						next kvLO23oqzz unless index( $dentry, '.' );
						
						my $ftype = '&nbsp;';
						my $dir = 0;

						if( -d $dentry )
						{
							$ftype = '&lt;DIR&gt;';
							$dir = 1;
						}
						
						$working_area .= '<tr onMouseOver="this.bgColor=\'lightblue\'" onMouseOut="this.bgColor=\'white\'">';
						
						$working_area .= '<td width="1%">';
						$working_area .= $ftype;
						$working_area .= '</td>';
						
						
						$working_area .= '<td>';

						if( $dir )
						{
							$working_area .= '<a href="/admin/?action=files&location=' .
							                 encode_base64( File::Spec -> catdir( $location, $dentry ), '' ) .
							                 '">';
						}

						$working_area .= xml_quote( $dentry );
						
						if( $dir )
						{
							$working_area .= '</a>';
						}

						$working_area .= '</td>';


						$working_area .= '<td>';
						$working_area .= ( $dir ? '&nbsp;' : int( -s $dentry ) );
						$working_area .= '</td>';

						$working_area .= '<td>&nbsp;</td>';
						$working_area .= '<td>';
						$working_area .= '<a href="/admin/?action=files&location=' .
						                 $inputloc .
								 '&delete=' .
						                 encode_base64( $dentry, '' ) .
						                 '" title="Delete" onClick="return confirm(\'Really delete ' .
 						                 xml_quote( $dentry ) .
								 '?\')">x</a>';
						$working_area .= '</td>';

						
						
						$working_area .= '</tr>';
					}
					
					$working_area .= '</table>';
					
					closedir( $dirhandle );
				} else
				{
					$error_message = 'Failed to open directory ' . $location . ': ' . $!;
				}
SKIPDIRECTORYLISTING:


				chdir( $cwd );
			} else
			{
				$error_message = 'CANT CHDIR TO ' . $location . ': ' . $!;
			}
		}
		


		&add_replace( 'WORKING_AREA'  => $working_area,
			      'ERROR_MESSAGE' => $error_message,
			      'INPUTLOC'      => $inputloc,
			      'LOCATION'      => $location );
		$outcome = &template_process( $WOBJ );

	} elsif( $action eq 'macros' )
	{
		my $working_area = "";
		my $hosts = &all_hosts();

		my $filterval = $cgi -> param( 'filter' );
		my $host = int( $cgi -> param( 'host' ) );

		if( $subaction eq 'list' )
		{
			my $address = $cgi -> param( 'address' );
			my $showonly = $cgi -> param( 'showonly' );
			my $content_filter = $cgi -> param( 'content_filter' );

			my $sql = "SELECT macros.name AS name,macros.id AS id,macros.host AS host,macros.address AS address,macros.istext AS istext,language.lng AS lng FROM macros,language WHERE language.id=macros.lng ";

			if( $host )
			{
				$sql .= " AND macros.host=" . &dbquote( $host );
			}

			if( $filterval )
			{
				$sql .= " AND macros.name ILIKE " . &dbquote( '%' . $filterval . '%' );
			}

			if( $content_filter )
			{
				$sql .= sprintf( " AND macros.body ILIKE %s", &dbquote( '%' . $content_filter . '%' ) );
			}

			if( $address )
			{
				$sql .= " AND macros.address=" . &dbquote( $address );
			}

			if( $showonly eq 'str' )
			{
				$sql .= " AND macros.istext=false";
			} elsif( $showonly eq 'text' )
			{
				$sql .= " AND macros.istext=true";
			}
			
			$sql .= " ORDER BY macros.name ASC";

			my $sth = &dbprepare( $sql );
			$sth -> execute();
			
			if( $sth -> rows() > 0 )
			{
				$working_area = 'INCLUDE:__int_admin_macros_list';
				my $table_body = "";

				while( my $data = $sth -> fetchrow_hashref() )
				{
					$table_body .= '<tr><td>' .
					               '<a href="/admin/?action=macros&sub=open&id=' .
						       $data -> { "id" } .
						       '">' .
					               $data -> { "name" } .
						       '</a></td><td>' . 
						       $hosts -> { $data -> { "host" } } -> { "host" } .
						       '</td><td>' .
						       ( $data -> { "istext" } ? 'text' : 'string' ) .
						       '</td><td>' .
						       $data -> { "address" } .
						       '</td><td>' .
						       $data -> { "lng" } .
						       '</td><td>' .
						       '[ <a onClick="return confirm(&quot;' .
						       'Really delete ' .
						       $data -> { "name" } .
						       '?&quot;)" href="/admin/?action=macros&sub=delete&id=' .
						       $data -> { "id" } .
						       '">' .
						       'delete' .
						       '</a> ]' .
						       '</td></tr>';
				}

				&add_replace( 'MACROS_ROWS' => $table_body );

			} else
			{
				$working_area = "No macros found. (" . $sth -> rows() . ") <a href='javascript:history.back()'>back</a><p>";
			}

			$sth -> finish();
			


		} elsif( $subaction eq 'new' )
		{
			my $rand_name = uc( md5_hex( rand() ) );

			my $newid = &seqnext( 'macros_id_seq' );

			my $sql = sprintf( "INSERT INTO macros (id,name,lng,host,address) values (%s,%s,%s,%s,%s)",
					   map { &dbquote( $_ ) } ( $newid,
								    $rand_name,
								    $WOBJ -> { "RLNGS" } -> { $WOBJ -> { "LNG" } },
								    $WOBJ -> { "HOST" } -> { "id" },
								    'root' ) );
			my $sth = &wdbprepare( $sql );
			my $error = 0;
			$sth -> execute() or $error = 1;

			if( $error )
			{
				$working_area = &__htmlerrmsg( 'ERROR: ' . &wdbgeterror() ) . '<p>';
			} else
			{
				$sth -> finish();

 				my $custom_header = { 'Location' => '/admin/?action=macros&sub=open&id=' . $newid };

 				$outcome -> { "code" } = 302;
 				$outcome -> { "headers" } = $custom_header;
 				$outcome -> { "ctype" } = "";
				
 				goto ADMINWORKFINISHED;


			}

			

		} elsif( $subaction eq 'update' )
		{
			my $id = int( $cgi -> param( "id" ) );

			my $sql = sprintf( "UPDATE macros SET body=%s, name=%s, host=%s, address=%s, lng=%s WHERE id=%s",
					   map { &dbquote( $_ ) } ( $cgi -> param( 'macrosbody' ),
								    uc( $cgi -> param( 'name' ) ),
								    $cgi -> param( 'host' ),
								    $cgi -> param( 'address' ),
								    $cgi -> param( 'lng' ),
								    $id ) );

			if( &wdbdo( $sql ) )
			{
				$working_area = &__htmlokmsg( '<b>OK</b>' ) . '<p>';
			} else
			{
				$working_area = &__htmlerrmsg( '<b>ERROR: ' .
				                &wdbgeterror() .
						'</b>' ) . '<p>';
			}

		} elsif( $subaction eq 'delete' )
		{
			my $id = int( $cgi -> param( "id" ) );
			
			my $sql = sprintf( "DELETE FROM macros WHERE id=%s", &dbquote( $id ) );
			if( &wdbdo( $sql ) )
			{
				$working_area = &__htmlokmsg( '<b>OK</b>' ) . '<p>';
			} else
			{
				$working_area = &__htmlerrmsg( '<b>ERROR: ' .
				                &wdbgeterror() .
						'</b>' ) . '<p>';
			}
		} elsif( $subaction eq 'open' )
		{
			$working_area = 'INCLUDE:__int_admin_macros_edit';
			my $id = int( $cgi -> param( "id" ) );
			my $editmode = $cgi -> param( "mode" );

			if( $editmode eq 'fancy' )
			{
				$working_area = 'INCLUDE:__int_admin_macros_edit_fancy';
			}
			

			my %record = &meta_get_records( Table  => 'macros',
							Fields => [ 'id', 'name', 'body', 'istext', 'host', 'address', 'lng' ],
							Where => sprintf( "id=%s", &dbquote( $id ) ) );

			my %languages = &meta_get_records( Table  => 'language',
							   Fields => [ 'id', 'lng' ] );

			my $subst_macros_body = $record{ $id } -> { "body" };

			&add_replace( 'MACROS_NAME' => $record{ $id } -> { "name" },
				      'MACROS_HOST' => $hosts -> { $record{ $id } -> { "host" } } -> { "host" },
				      'MACROS_ADDR' => $record{ $id } -> { "address" },
				      'MACROS_BODY' => xml_quote( $subst_macros_body ),
				      'MACROS_LNG'  => $languages{ $record{ $id } -> { "lng" } } -> { "lng" },
				      'MACROS_ID'   => $id );

			
			my $hosts_options = "";
			my $hs_func_body = "document.getElementById( 'addressDiv' ).innerHTML = '&nbsp;'; ";
			
			foreach my $hid ( sort {
				
				$hosts -> { $a } -> { "host" }
				cmp
				$hosts -> { $b } -> { "host" }
				
			} keys %$hosts )
			{
				$hosts_options .= '<OPTION value="' .
				    $hid .
				    '" ' .
				    ( $hid == $record{ $id } -> { "host" } ? 'SELECTED' : '' ) .
				    '>' .
				    $hosts -> { $hid } -> { "host" } .
				    '</OPTION>';
				
				
				my $innerHTML_addr = "";
				my $innerHTML_lng = "";
				
				{
					my $host_dir = File::Spec -> catdir( CONF_VARPATH, 'hosts', $hosts -> { $hid } -> { "host" }, 'htdocs'  );
					
					my @tree = sort map { &form_address( File::Spec -> abs2rel( $_, $host_dir ) or 'root' ) } grep { ( -d $_ ) and ( -f File::Spec -> catfile( $_, 'wendyaddr' ) ) } &build_directory_tree( $host_dir );
					push @tree, 'ANY';
					
					$innerHTML_addr = '<SELECT name="address" id="addressSelect">';
					
					foreach my $te ( @tree )
					{
						$te = xml_quote( $te );
						$innerHTML_addr .= '<OPTION value="' .
						              $te .
							      '" ' .
							      ( $te eq $record{ $id } -> { "address" } ? ' SELECTED ' : '' ) .
							      '>' .
							      $te .
							      "</OPTION>";
					}
					
					$innerHTML_addr .= '</SELECT>';


					$innerHTML_lng = '<SELECT id="macrosLngSelect" name="lng">';


					{
						my %host_languages = &get_host_languages( $hid );

						foreach my $lid ( sort {
							                       $host_languages{ $a }
									       cmp
									       $host_languages{ $b }
							               } keys %host_languages )
						{
							$innerHTML_lng .= '<OPTION value="' . $lid . '" ' .
							                  ( $lid == $record{ $id } -> { "lng" } ? 'SELECTED' : '' ) .
							                  '>' . $host_languages{ $lid } . '</OPTION>';
						}
					}

					$innerHTML_lng .= '</SELECT>';

					
					
				}
				
				$hs_func_body .= "if( document.getElementById( 'hostSelect' ).value == " . $hid . ") " .
				    "{ document.getElementById( 'addressDiv' ).innerHTML='" . $innerHTML_addr . "';".
				    "document.getElementById( 'macrosLngSelDiv' ).innerHTML='" . $innerHTML_lng . "';".
				    " }";
				
				
			}
			&add_replace( 'HOSTS_OPTIONS'     => $hosts_options,
				      'HS_FUNC_BODY'      => $hs_func_body );

		} else
		{
			$working_area = 'INCLUDE:__int_admin_macros_open';

			my $hosts_options = "";
			my $hs_func_body = "document.getElementById( 'addressDiv' ).innerHTML = '(host not selected)'; ";
			
			foreach my $hid ( sort {
				
				$hosts -> { $a } -> { "host" }
				cmp
				    $hosts -> { $b } -> { "host" }
				
			} keys %$hosts )
			{
				$hosts_options .= '<OPTION value="' .
				    $hid .
				    '">' .
				    $hosts -> { $hid } -> { "host" } .
				    '</OPTION>';
				
				
				my $innerHTML = "";
				
				{
					my $host_dir = File::Spec -> catdir( CONF_VARPATH, 'hosts', $hosts -> { $hid } -> { "host" }, 'htdocs'  );
					
					my @tree = sort map { &form_address( File::Spec -> abs2rel( $_, $host_dir ) or 'root' ) } grep { ( -d $_ ) and ( -f File::Spec -> catfile( $_, 'wendyaddr' ) ) } &build_directory_tree( $host_dir );
					push @tree, 'ANY';
					
					$innerHTML = '<SELECT name="address" id="addressSelect"><OPTION value="0"> ... </OPTION>';
					
					foreach my $te ( @tree )
					{
						$te = xml_quote( $te );
						$innerHTML .= '<OPTION value="' . $te . '">' . $te . "</OPTION>";
					}
					
					$innerHTML .= '</SELECT>';
					
					
				}
				
				$hs_func_body .= "if( document.getElementById( 'hostSelect' ).value == " . $hid . ") " .
				    "{ document.getElementById( 'addressDiv' ).innerHTML='" . $innerHTML . "'; }";
				
				
			}
			&add_replace( 'HOSTS_OPTIONS' => $hosts_options,
				      'HS_FUNC_BODY'  => $hs_func_body );
			
		}
		
		
		$WOBJ -> { "HPATH" } = "_admin_macros";
		&add_replace( 'WORKING_AREA' => $working_area );
		$outcome = &template_process( $WOBJ );

	}

ADMINWORKFINISHED:
	$outcome -> { "nocache" } = 1;
	return $outcome;

}

sub __htmlerrmsg
{
	my $msg = shift;

	return '<font color="red">' .
	       $msg .
	       '</font>';

}

sub __htmlokmsg
{
	my $msg = shift;

	return '<font color="green">' .
	       $msg .
	       '</font>';

}


1;

