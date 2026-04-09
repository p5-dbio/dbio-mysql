package DBIO::MySQL::Introspect::Columns;
# ABSTRACT: Introspect MySQL/MariaDB columns
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Fetches column metadata from C<information_schema.columns>. The
C<column_type> field is preserved (e.g. C<varchar(100)>, C<int(11)
unsigned>) since it round-trips faithfully through MySQL DDL. The
distilled C<data_type> (e.g. C<varchar>, C<int>) is also captured.

=cut

=method fetch

    my $columns = DBIO::MySQL::Introspect::Columns->fetch($dbh, $tables);

Returns a hashref keyed by table name. Each value is an arrayref of
column hashrefs (in declaration order) with keys: C<column_name>,
C<data_type>, C<column_type>, C<not_null>, C<default_value>,
C<is_auto_increment>, C<is_pk>, C<character_set>, C<collation>,
C<comment>, C<extra>.

=cut

sub fetch {
  my ($class, $dbh, $tables) = @_;
  my %columns;

  my $sth = $dbh->prepare(q{
    SELECT
      table_name,
      column_name,
      ordinal_position,
      data_type,
      column_type,
      is_nullable,
      column_default,
      column_key,
      extra,
      character_set_name,
      collation_name,
      column_comment
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
    ORDER BY table_name, ordinal_position
  });
  $sth->execute;

  while (my $row = $sth->fetchrow_hashref) {
    next unless exists $tables->{ $row->{table_name} };

    my $extra = $row->{extra} // '';
    my $auto  = ($extra =~ /\bauto_increment\b/i) ? 1 : 0;
    my $is_pk = ($row->{column_key} // '') eq 'PRI' ? 1 : 0;

    push @{ $columns{ $row->{table_name} } }, {
      column_name       => $row->{column_name},
      data_type         => $row->{data_type},
      column_type       => $row->{column_type},
      not_null          => (uc($row->{is_nullable} // '') eq 'NO') ? 1 : 0,
      default_value     => $row->{column_default},
      is_auto_increment => $auto,
      is_pk             => $is_pk,
      character_set     => $row->{character_set_name},
      collation         => $row->{collation_name},
      comment           => $row->{column_comment},
      extra             => $extra,
    };
  }

  return \%columns;
}

1;
