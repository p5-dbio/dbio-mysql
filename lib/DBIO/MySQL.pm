package DBIO::MySQL;
# ABSTRACT: MySQL-specific schema management for DBIO
our $VERSION = '0.900';

use strict;
use warnings;

use base 'DBIO';

=head1 SYNOPSIS

  package MyApp::Schema;
  use base 'DBIO::Schema';
  __PACKAGE__->load_components('DBIO::MySQL');

  # storage_type is set to +DBIO::MySQL::Storage by the component
  my $schema = __PACKAGE__->connect($dsn, $user, $pass);

=head1 DESCRIPTION

L<DBIO::MySQL> is the MySQL driver component for DBIO.

When this component is loaded into a schema class, C<connection()> sets
L<DBIO::Schema/storage_type> to C<+DBIO::MySQL::Storage>, which enables
MySQL-specific storage behavior automatically.

For MariaDB-specific behavior, see L<DBIO::MySQL::MariaDB> and
L<DBIO::MySQL::Storage::MariaDB>.

=head1 MIGRATION NOTES

MySQL storage and SQLMaker classes were split out of the historical
DBIx::Class monolithic distribution:

=over 4

=item *

Old: C<DBIx::Class::Storage::DBI::mysql>

=item *

New: C<DBIO::MySQL::Storage>

=item *

Old: C<DBIx::Class::Storage::DBI::MariaDB>

=item *

New: C<DBIO::MySQL::Storage::MariaDB>

=item *

Old: C<DBIx::Class::SQLMaker::MySQL>

=item *

New: C<DBIO::MySQL::SQLMaker>

=back

If C<DBIO-MySQL> is installed, core L<DBIO::Storage::DBI> can autodetect MySQL
DSNs and load the new storage class via the driver registry.

=head1 TESTING

Integration tests in this distribution use:

  DBIOTEST_MYSQL_DSN
  DBIOTEST_MYSQL_USER
  DBIOTEST_MYSQL_PASS

SQLMaker-focused tests can run offline via L<DBIO::Test> with:

  storage_type => 'DBIO::MySQL::Storage'

Replicated-path tests can reuse the same harness with:

  replicated   => 1,
  storage_type => 'DBIO::MySQL::Storage'

=head1 METHODS

=method connection

Overrides L<DBIO/connection> to force C<+DBIO::MySQL::Storage> as
C<storage_type>.

=cut

sub connection {
  my ($self, @info) = @_;
  $self->storage_type('+DBIO::MySQL::Storage');
  return $self->next::method(@info);
}

1;
