package DBIO::MySQL::Introspect::Tables;
# ABSTRACT: Introspect MySQL/MariaDB tables
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Fetches table and view metadata from C<information_schema.tables>.
Filters to the current database (C<DATABASE()>).

=cut

=method fetch

    my $tables = DBIO::MySQL::Introspect::Tables->fetch($dbh);

Returns a hashref keyed by table name. Each value is a hashref with
keys: C<table_name>, C<kind> (C<table> or C<view>), C<engine>,
C<table_collation>, C<row_format>, C<comment>.

=cut

sub fetch {
  my ($class, $dbh) = @_;

  my $sth = $dbh->prepare(q{
    SELECT
      table_name      AS name,
      table_type      AS table_type,
      engine          AS engine,
      table_collation AS table_collation,
      row_format      AS row_format,
      table_comment   AS comment
    FROM information_schema.tables
    WHERE table_schema = DATABASE()
    ORDER BY table_name
  });
  $sth->execute;

  my %tables;
  while (my $row = $sth->fetchrow_hashref) {
    my $kind = ($row->{table_type} // '') eq 'VIEW' ? 'view' : 'table';
    $tables{ $row->{name} } = {
      table_name      => $row->{name},
      kind            => $kind,
      engine          => $row->{engine},
      table_collation => $row->{table_collation},
      row_format      => $row->{row_format},
      comment         => $row->{comment},
    };
  }

  return \%tables;
}

1;
