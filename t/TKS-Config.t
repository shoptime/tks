use strict;
use warnings;

use POSIX;
use Test::More;

plan tests => 4;

use_ok('TKS::Config');

TKS::Config->import(qw(config config_set config_delete));

is(config(), undef, 'config() returns undef');

config_delete('test', 'pants');
config_set('test', 'pants', 'good!');
config_set('test', 'pants', 'awesome!');
config_set('test', 'pants', 'awesome!');
is(config('test', 'pants'), 'awesome!', 'config_set() => config()');
config_delete('test', 'pants');
is(config('test', 'pants'), undef, 'config_set() => config()');
