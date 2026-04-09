package DBIO::MySQL::Storage::MariaDB;
# ABSTRACT: MariaDB-specific storage for DBIO
our $VERSION = '0.900000';

use strict;
use warnings;

use base qw/DBIO::MySQL::Storage/;

DBIO::Storage::DBI->register_driver('MariaDB' => __PACKAGE__);

__PACKAGE__->sql_maker_class('DBIO::MySQL::SQLMaker::MariaDB');

=head1 SYNOPSIS

  package MyApp::Schema;
  use base 'DBIO::Schema';
  __PACKAGE__->load_components('MySQL::MariaDB');

  my $schema = MyApp::Schema->connect($dsn, $user, $pass);

=head1 DESCRIPTION

MariaDB-specific storage backend for L<DBIO>. Extends L<DBIO::MySQL::Storage>
with adaptations for L<DBD::MariaDB>:

=over 4

=item *

Reads C<mariadb_insertid> instead of C<mysql_insertid> for last-insert-id
retrieval.

=item *

Disables C<mariadb_auto_reconnect> by default, consistent with the MySQL
storage behavior, to prevent silent transaction loss.

=item *

Replication status queries use C<SHOW REPLICA STATUS> (MariaDB 10.5+) with
fallback to C<SHOW SLAVE STATUS> for older servers.

=back

This class is auto-registered for the C<MariaDB> DBI driver and is activated
when L<DBIO::MySQL::MariaDB/connection> is called.

=cut

sub _dbh_last_insert_id {
  my ($self, $dbh, $source, $col) = @_;
  $dbh->{mariadb_insertid};
}

sub _run_connection_actions {
  my $self = shift;

  if (
    $self->_dbh->{mariadb_auto_reconnect}
      and
    ! exists $self->_dbio_connect_attributes->{mariadb_auto_reconnect}
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

=method is_replicating

Returns true if the connected MariaDB replica is currently replicating (both
IO and SQL threads running). Queries C<SHOW REPLICA STATUS> first, falling
back to C<SHOW SLAVE STATUS> for MariaDB versions older than 10.5.

=cut

sub lag_behind_master {
  my $status = shift->_get_dbh->selectrow_hashref('SHOW REPLICA STATUS')
    || shift->_get_dbh->selectrow_hashref('SHOW SLAVE STATUS');
  return $status->{Seconds_Behind_Master};
}

=method lag_behind_master

Returns the number of seconds the replica is behind the master. Queries
C<SHOW REPLICA STATUS> first, falling back to C<SHOW SLAVE STATUS> for older
servers.

=seealso

=over 4

=item * L<DBIO::MySQL::MariaDB> - Schema component that activates this storage

=item * L<DBIO::MySQL::Storage> - MySQL parent class

=item * L<DBIO::MySQL> - Main distribution entry point

=back

=cut

1;
