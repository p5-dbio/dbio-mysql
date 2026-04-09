package DBIO::MySQL::Introspect::Indexes;
# ABSTRACT: Introspect MySQL/MariaDB indexes
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Fetches index metadata from C<information_schema.statistics>. Indexes
are grouped by C<table_name> + C<index_name> with columns ordered by
C<seq_in_index>. The PRIMARY KEY and UNIQUE constraint indexes are
included with C<origin> set so the diff layer can skip auto-generated
indexes.

=cut

=method fetch

    my $indexes = DBIO::MySQL::Introspect::Indexes->fetch($dbh, $tables);

Returns a hashref keyed by table name. Each value is a hashref keyed by
index name. Each index has: C<index_name>, C<is_unique>, C<columns>,
C<index_type> (BTREE/HASH/FULLTEXT/SPATIAL), C<origin> (C<pk>=primary,
C<u>=unique constraint, C<c>=created).

=cut

sub fetch {
  my ($class, $dbh, $tables) = @_;
  my %indexes;

  my $sth = $dbh->prepare(q{
    SELECT
      table_name,
      index_name,
      non_unique,
      seq_in_index,
      column_name,
      index_type
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
    ORDER BY table_name, index_name, seq_in_index
  });
  $sth->execute;

  while (my $row = $sth->fetchrow_hashref) {
    next unless exists $tables->{ $row->{table_name} };

    my $idx_name   = $row->{index_name};
    my $is_unique  = $row->{non_unique} ? 0 : 1;

    my $origin;
    if ($idx_name eq 'PRIMARY') {
      $origin = 'pk';
    }
    elsif ($is_unique) {
      $origin = 'u';
    }
    else {
      $origin = 'c';
    }

    my $entry = $indexes{ $row->{table_name} }{$idx_name} //= {
      index_name => $idx_name,
      is_unique  => $is_unique,
      columns    => [],
      index_type => $row->{index_type},
      origin     => $origin,
    };
    $entry->{columns}[ $row->{seq_in_index} - 1 ] = $row->{column_name};
  }

  return \%indexes;
}

1;
