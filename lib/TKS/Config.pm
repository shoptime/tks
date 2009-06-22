package TKS::Config;

use strict;
use warnings;
use Exporter 'import';
use Config::IniFiles;
use File::Slurp;
use JSON qw(encode_json decode_json);

our @EXPORT = qw(config);
our @EXPORT_OK = qw(config_set config_delete);

my $config;
my $config_store;
my $reverse_request_map;
my $store_filename;

sub config {
    my ($section, $key) = @_;

    return unless $section;

    return $reverse_request_map->{$key} if $section eq 'reverserequestmap';

    return $config_store->{$section}{$key} || $config->val($section, $key);
};

sub config_set {
    my ($section, $key, $value) = @_;

    my $existing_value = config($section, $key);

    if ( not defined $existing_value or $existing_value ne $value ) {
        $config_store->{$section}{$key} = $value;
        write_store();
    }
}

sub config_delete {
    my ($section, $key) = @_;

    delete $config_store->{$section}{$key};
    write_store();
}

sub write_store {
    write_file($store_filename, encode_json($config_store));
}

BEGIN {
    $store_filename = "$ENV{HOME}/.tksinfo";

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

    $config_store = {};
    if ( -f $store_filename ) {
        $config_store = decode_json(read_file($store_filename));
    }
};

1;
