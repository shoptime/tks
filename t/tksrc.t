use strict;
use warnings;

use POSIX;
use Test::More;

plan tests => 5;

$ENV{TKS_RC} = 't/tksrc.ini';

use_ok('TKS::Config');

is(config('requestmap', 'test1'), '12345'              , 'Standard WRMS request identifier');
is(config('requestmap', 'test2'), 'frank pants'        , 'Request with whitespace in the identifier');
is(config('requestmap', 'test3'), 'trailing whitespace', 'Request with trailing whitespace in the identifier');
is(config('requestmap', 'test4'), 'leading whitespace' , 'Request with leading whitespace in the identifier');

