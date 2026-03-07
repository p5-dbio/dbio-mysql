use strict;
use warnings;
use Test::More;

my @modules = qw(
  DBIO::MySQL
  DBIO::MySQL::Storage
  DBIO::MySQL::MariaDB
  DBIO::MySQL::Storage::MariaDB
  DBIO::MySQL::SQLMaker
);

plan tests => scalar @modules;

for my $mod (@modules) {
  use_ok($mod);
}
