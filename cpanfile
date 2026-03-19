requires 'perl', '5.020';
requires 'DBIO';
requires 'DBI';
requires 'namespace::clean';

recommends 'DBD::mysql';
recommends 'DBD::MariaDB';

on test => sub {
  requires 'Test::More', '0.98';
  requires 'Test::Exception';
  requires 'Test::Warn';
  requires 'DBI::Const::GetInfoType';
  requires 'Scalar::Util';
  requires 'Time::HiRes';
  requires 'DBIO::Test';
};
