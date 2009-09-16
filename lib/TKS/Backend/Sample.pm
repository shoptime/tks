# Copyright (C) 2009 Catalyst IT Ltd (http://www.catalyst.net.nz)
#
# This file is distributed under the same terms as tks itself.
package TKS::Backend::Sample;

use strict;
use warnings;
use base 'TKS::Backend';
use TKS::Timesheet;

# Sample .tksrc stuff:
#
#   [sample]
#   defaultfile=~/doc/timesheet.tks
#   defaultfilter=week
#   backend = TKS::Backend::Sample
#   configparam1 = configvalue1
#


sub init {
    my ($self) = @_;

    my $runcount = $self->instance_config('runcount');

    $runcount ||= 0;

    $runcount++;

    print "init() - " . $self->instance_config('configparam1') . ' - run ' . $runcount . " times\n";

    $self->instance_config_set('runcount', $runcount);
}

sub get_timesheet {
    my ($self, $dates, $user) = @_;

    print "get_timesheet() - returning empty timesheet\n";

    my $timesheet = TKS::Timesheet->new;

    # TODO: you should populate $timesheet with data from your backend here

    return $timesheet;
}

sub add_timesheet {
    my ($self, $timesheet, $show_progress) = @_;

    print "add_timesheet() - null operation\n";

    # TODO: you should send data from $timesheet to your backend
}

sub valid_request {
    my ($self, $request) = @_;

    # should return 0 here if $request isn't valid

    return 1;
}

1;
