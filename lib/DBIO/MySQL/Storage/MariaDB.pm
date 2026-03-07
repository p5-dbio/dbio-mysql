package DBIO::MySQL::Storage::MariaDB;
# ABSTRACT: MariaDB-specific storage for DBIO

use strict;
use warnings;

use base qw/DBIO::MySQL::Storage/;

DBIO::Storage::DBI->register_driver('MariaDB' => __PACKAGE__);

sub _dbh_last_insert_id {
  my ($self, $dbh, $source, $col) = @_;
  $dbh->{mariadb_insertid};
}

sub _run_connection_actions {
  my $self = shift;

  if (
    $self->_dbh->{mariadb_auto_reconnect}
      and
    ! exists $self->_dbic_connect_attributes->{mariadb_auto_reconnect}
  ) {
    $self->_dbh->{mariadb_auto_reconnect} = 0;
  }

  $self->DBIO::Storage::DBI::_run_connection_actions(@_);
}

sub is_replicating {
  my $status = shift->_get_dbh->selectrow_hashref('SHOW REPLICA STATUS')
    || shift->_get_dbh->selectrow_hashref('SHOW SLAVE STATUS');
  return ($status->{Slave_IO_Running} eq 'Yes') && ($status->{Slave_SQL_Running} eq 'Yes');
}

sub lag_behind_master {
  my $status = shift->_get_dbh->selectrow_hashref('SHOW REPLICA STATUS')
    || shift->_get_dbh->selectrow_hashref('SHOW SLAVE STATUS');
  return $status->{Seconds_Behind_Master};
}

1;
