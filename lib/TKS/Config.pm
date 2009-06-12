package TKS::Config;

use strict;
use warnings;
use Exporter 'import';
use Config::IniFiles;

our @EXPORT = qw(config);
our @EXPORT_OK = qw(config_set config_delete);

my $config;
my $reverse_request_map;

sub config {
    my ($section, $key) = @_;

    return unless $section;

    return $reverse_request_map->{$key} if $section eq 'reverserequestmap';

    return $config->val($section, $key);
};

sub config_set {
    my ($section, $key, $value) = @_;

    my $existing_value = config($section, $key);

    if ( not defined $existing_value or $existing_value ne $value ) {
        $config->newval($section, $key, $value);
        $config->RewriteConfig;
    }
}

sub config_delete {
    my ($section, $key) = @_;

    $config->delval($section, $key);
    $config->RewriteConfig;
}

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

    $config = Config::IniFiles->new( -file => $file );

    foreach my $key ( $config->Parameters('requestmap') ) {
        my $value = $config->val('requestmap', $key);
        if ( ref $value or $value =~ /\n/ ) {
            die "[requestmap] entry '$key' has multiple mappings in $file\n";
        }
        $reverse_request_map->{$value} = $key;
    }
};

1;
