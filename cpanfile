requires 'perl', '5.020';
requires 'DBIO';
requires 'DBI';
requires 'namespace::clean';
requires 'DateTime::Format::MySQL';

recommends 'DBD::mysql';
recommends 'DBD::MariaDB';

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
