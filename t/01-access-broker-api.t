use strict;
use warnings;

use Test::More;

use DBIO::AccessBroker::Static;

{
  package TestSchema;
  use base 'DBIO::Schema';
  __PACKAGE__->load_components('MySQL');
}

my $broker = DBIO::AccessBroker::Static->new(
  dsn      => 'dbi:mysql:database=dbio_test;host=localhost',
  username => 'dbio',
  password => 'secret',
);

my $schema = TestSchema->connect($broker);

isa_ok $schema->storage, 'DBIO::MySQL::Storage';
is $schema->storage->access_broker, $broker, 'mysql storage keeps broker';
is $schema->storage->access_broker_mode, 'write', 'mysql storage defaults broker mode to write';

done_testing;
