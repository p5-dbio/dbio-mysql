requires 'perl', '5.020';
requires 'DBIO';
requires 'DBI';
requires 'namespace::clean';
requires 'DateTime::Format::MySQL';

# DBD::MariaDB bundles its own connector and works with MySQL and MariaDB.
# DBD::mysql requires system MySQL/MariaDB client libraries — install it
# only if you specifically need it.
recommends 'DBD::MariaDB';
recommends 'DBD::mysql';

on test => sub {
  recommends 'Kubernetes::REST';
  requires 'Test::More', '0.98';
  requires 'Test::Exception';
  requires 'Test::Warn';
  requires 'DBI::Const::GetInfoType';
  requires 'Scalar::Util';
  requires 'Time::HiRes';
  requires 'DBIO::Test';
};
