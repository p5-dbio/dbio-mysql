package DBIO::MySQL::Introspect;
# ABSTRACT: Introspect a MySQL/MariaDB database via information_schema
our $VERSION = '0.900000';

use strict;
use warnings;

use DBIO::MySQL::Introspect::Tables;
use DBIO::MySQL::Introspect::Columns;
use DBIO::MySQL::Introspect::Indexes;
use DBIO::MySQL::Introspect::ForeignKeys;

=head1 DESCRIPTION

C<DBIO::MySQL::Introspect> reads the live state of a MySQL or MariaDB
database via C<information_schema> and returns a unified model
hashref. It is the source side of the test-deploy-and-compare strategy
used by L<DBIO::MySQL::Deploy>.

    my $intro = DBIO::MySQL::Introspect->new(dbh => $dbh);
    my $model = $intro->model;
    # $model->{tables}, $model->{columns}, $model->{indexes}, $model->{foreign_keys}

The model shape mirrors L<DBIO::PostgreSQL::Introspect> and
L<DBIO::SQLite::Introspect> so the same diff/deploy patterns apply.

The introspection is scoped to the current database (the C<dbname>
component of the DSN) via C<DATABASE()> -- to introspect a different
schema, connect with that database in the DSN.

=cut

sub new { my ($class, %args) = @_; bless \%args, $class }

sub dbh { $_[0]->{dbh} }

=attr dbh

A connected C<DBI> handle for MySQL or MariaDB. Required.

=cut

sub model { $_[0]->{model} //= $_[0]->_build_model }

=method model

Returns the full introspected model hashref. Built lazily.

=cut

sub _build_model {
  my ($self) = @_;

  my $tables  = DBIO::MySQL::Introspect::Tables->fetch($self->dbh);
  my $columns = DBIO::MySQL::Introspect::Columns->fetch($self->dbh, $tables);
  my $indexes = DBIO::MySQL::Introspect::Indexes->fetch($self->dbh, $tables);
  my $fks     = DBIO::MySQL::Introspect::ForeignKeys->fetch($self->dbh, $tables);

  return {
    tables       => $tables,
    columns      => $columns,
    indexes      => $indexes,
    foreign_keys => $fks,
  };
}

1;
