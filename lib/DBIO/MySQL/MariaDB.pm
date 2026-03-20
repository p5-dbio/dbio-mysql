package DBIO::MySQL::MariaDB;
# ABSTRACT: MariaDB-specific schema management for DBIO
our $VERSION = '0.900';

use strict;
use warnings;

use base 'DBIO';

=head1 SYNOPSIS

  package MyApp::Schema;
  use base 'DBIO::Schema';
  __PACKAGE__->load_components('MySQL::MariaDB');

  my $schema = MyApp::Schema->connect($dsn, $user, $pass);

=head1 DESCRIPTION

MariaDB-specific schema component for L<DBIO>. Load this component instead
of L<DBIO::MySQL> when connecting to a MariaDB server.

When C<connection()> is called, the storage class is set to
L<DBIO::MySQL::Storage::MariaDB>, which uses the C<mariadb_*> DBD attributes
provided by L<DBD::MariaDB> rather than the C<mysql_*> attributes used by
L<DBD::mysql>.

=cut

sub connection {
  my ($self, @info) = @_;
  $self->storage_type('+DBIO::MySQL::Storage::MariaDB');
  return $self->next::method(@info);
}

=method connection

Overrides L<DBIO/connection> to set C<storage_type> to
C<+DBIO::MySQL::Storage::MariaDB> before delegating to the parent.

=seealso

=over 4

=item * L<DBIO::MySQL> - MySQL equivalent of this component

=item * L<DBIO::MySQL::Storage::MariaDB> - Storage backend activated by this component

=back

=cut

1;
