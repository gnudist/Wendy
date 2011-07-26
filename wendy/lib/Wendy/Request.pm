use strict;

package Wendy::Request;

use Moose;

has 'mod_perl_req' => ( is => 'rw', isa => 'Apache2::RequestRec' );


no Moose;

42;
