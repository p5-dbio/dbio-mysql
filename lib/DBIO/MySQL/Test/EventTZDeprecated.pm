package # hide from PAUSE
    DBIO::MySQL::Test::EventTZDeprecated;
# ABSTRACT: Test result class using deprecated extra => { timezone => ... } syntax

use strict;
use warnings;

use base qw/DBIO::Test::BaseResult/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);

__PACKAGE__->table('event');

__PACKAGE__->add_columns(
  id => { data_type => 'integer', is_auto_increment => 1 },

  starts_at => {
    data_type => 'date',
    extra     => { timezone => 'America/Chicago' },
    datetime_undef_if_invalid => 1,
  },

  created_on => {
    data_type => 'datetime',
    extra     => { timezone => 'America/Chicago' },
  },
);

__PACKAGE__->set_primary_key('id');

1;
