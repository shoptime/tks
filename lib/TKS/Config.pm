package TKS::Config;

use strict;
use warnings;
use Exporter 'import';
use Config::IniFiles;

our @EXPORT = qw(config);

our $config;

sub config {
    my ($section, $key) = @_;

    return $config->val($section, $key);
};

BEGIN {
    my $file;
    foreach my $potential_file ( qw( .rc/tks .tksrc ) ) {
        if ( -r "$ENV{HOME}/$potential_file" ) {
            $file = "$ENV{HOME}/$potential_file";
            last;
        }
    }
    $file ||= "$ENV{HOME}/.rc/tks";

    mkdir "$ENV{HOME}/.rc" if $file eq "$ENV{HOME}/.rc/tks" and not -d "$ENV{HOME}/.rc";

    unless ( -e $file ) {
        open FH, '>', $file;
        close FH;
    }

    $config = Config::IniFiles->new( -file => $file, -allowempty => 1 );
};

1;
