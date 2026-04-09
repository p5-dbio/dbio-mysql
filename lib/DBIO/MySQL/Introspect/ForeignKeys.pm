package DBIO::MySQL::Introspect::ForeignKeys;
# ABSTRACT: Introspect MySQL/MariaDB foreign keys
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Fetches foreign key metadata by joining
C<information_schema.key_column_usage> with
C<information_schema.referential_constraints>. Composite FKs are grouped
by constraint name.

=cut

=method fetch

    my $fks = DBIO::MySQL::Introspect::ForeignKeys->fetch($dbh, $tables);

Returns a hashref keyed by table name. Each value is an arrayref of FK
hashrefs with keys: C<constraint_name>, C<from_columns>, C<to_table>,
C<to_columns>, C<on_update>, C<on_delete>.

=cut

sub fetch {
  my ($class, $dbh, $tables) = @_;
  my %fks;

  my $sth = $dbh->prepare(q{
    SELECT
      kcu.table_name,
      kcu.constraint_name,
      kcu.column_name,
      kcu.referenced_table_name,
      kcu.referenced_column_name,
      kcu.ordinal_position,
      rc.update_rule,
      rc.delete_rule
    FROM information_schema.key_column_usage kcu
    JOIN information_schema.referential_constraints rc
      ON  rc.constraint_schema = kcu.table_schema
      AND rc.constraint_name   = kcu.constraint_name
    WHERE kcu.table_schema = DATABASE()
      AND kcu.referenced_table_name IS NOT NULL
    ORDER BY kcu.table_name, kcu.constraint_name, kcu.ordinal_position
  });
  $sth->execute;

  my %by_constraint;
  while (my $row = $sth->fetchrow_hashref) {
    next unless exists $tables->{ $row->{table_name} };

    my $key = "$row->{table_name}\0$row->{constraint_name}";
    my $entry = $by_constraint{$key} //= {
      table_name      => $row->{table_name},
      constraint_name => $row->{constraint_name},
      from_columns    => [],
      to_table        => $row->{referenced_table_name},
      to_columns      => [],
      on_update       => $row->{update_rule},
      on_delete       => $row->{delete_rule},
    };
    push @{ $entry->{from_columns} }, $row->{column_name};
    push @{ $entry->{to_columns} },   $row->{referenced_column_name};
  }

  for my $entry (values %by_constraint) {
    my $tbl = delete $entry->{table_name};
    push @{ $fks{$tbl} }, $entry;
  }

  return \%fks;
}

1;
