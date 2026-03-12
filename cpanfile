requires 'perl', '5.020';
requires 'DBIO';
requires 'DBI';
requires 'DBD::mysql';
requires 'namespace::clean';

on test => sub {
  requires 'Test::More', '0.98';
  requires 'Test::Exception';
  requires 'Test::Warn';
  requires 'DBI::Const::GetInfoType';
  requires 'Scalar::Util';
  requires 'Path::Class';
  requires 'Time::HiRes';
  requires 'DBIO::Test';
};
