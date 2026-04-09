package DBIO::MySQL::Diff::Column;
# ABSTRACT: Diff operations for MySQL/MariaDB columns
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

Represents a column-level diff operation in MySQL/MariaDB. Unlike
SQLite, MySQL has full C<ALTER TABLE> support so all of C<ADD COLUMN>,
C<DROP COLUMN>, and C<MODIFY COLUMN> are emitted directly.

Brand-new tables get their columns inline via L<DBIO::MySQL::Diff::Table>
-- this module only sees columns of tables that exist in both source
and target.

=cut

sub new { my ($class, %args) = @_; bless \%args, $class }

sub action      { $_[0]->{action} }
sub table_name  { $_[0]->{table_name} }
sub column_name { $_[0]->{column_name} }
sub old_info    { $_[0]->{old_info} }
sub new_info    { $_[0]->{new_info} }

=method diff

=cut

sub diff {
  my ($class, $source_cols, $target_cols, $source_tables, $target_tables) = @_;
  my @ops;

  for my $table_name (sort keys %$target_cols) {
    next unless exists $source_tables->{$table_name}
             && exists $target_tables->{$table_name};

    my %source_by_name = map { $_->{column_name} => $_ }
      @{ $source_cols->{$table_name} // [] };
    my %target_by_name = map { $_->{column_name} => $_ }
      @{ $target_cols->{$table_name} // [] };

    for my $col_name (sort keys %target_by_name) {
      my $tgt = $target_by_name{$col_name};

      if (!exists $source_by_name{$col_name}) {
        push @ops, $class->new(
          action      => 'add',
          table_name  => $table_name,
          column_name => $col_name,
          new_info    => $tgt,
        );
        next;
      }

      my $src = $source_by_name{$col_name};
      my $changed = 0;
      $changed = 1 if lc($src->{column_type} // $src->{data_type} // '')
                   ne lc($tgt->{column_type} // $tgt->{data_type} // '');
      $changed = 1 if ($src->{not_null} // 0) != ($tgt->{not_null} // 0);
      $changed = 1 if (defined $src->{default_value} ? $src->{default_value} : '')
                   ne (defined $tgt->{default_value} ? $tgt->{default_value} : '');

      if ($changed) {
        push @ops, $class->new(
          action      => 'modify',
          table_name  => $table_name,
          column_name => $col_name,
          old_info    => $src,
          new_info    => $tgt,
        );
      }
    }

    for my $col_name (sort keys %source_by_name) {
      next if exists $target_by_name{$col_name};
      push @ops, $class->new(
        action      => 'drop',
        table_name  => $table_name,
        column_name => $col_name,
        old_info    => $source_by_name{$col_name},
      );
    }
  }

  return @ops;
}

=method as_sql

=cut

sub as_sql {
  my ($self) = @_;
  my $tbl = $self->table_name;
  my $col = $self->column_name;

  if ($self->action eq 'add') {
    my $info = $self->new_info;
    my $type = $info->{column_type} || $info->{data_type} || 'text';
    my $sql  = sprintf 'ALTER TABLE `%s` ADD COLUMN `%s` %s', $tbl, $col, $type;
    $sql .= ' NOT NULL' if $info->{not_null};
    if (defined $info->{default_value}) {
      $sql .= " DEFAULT '$info->{default_value}'";
    }
    return "$sql;";
  }
  if ($self->action eq 'drop') {
    return sprintf 'ALTER TABLE `%s` DROP COLUMN `%s`;', $tbl, $col;
  }
  if ($self->action eq 'modify') {
    my $info = $self->new_info;
    my $type = $info->{column_type} || $info->{data_type} || 'text';
    my $sql  = sprintf 'ALTER TABLE `%s` MODIFY COLUMN `%s` %s', $tbl, $col, $type;
    $sql .= ' NOT NULL' if $info->{not_null};
    if (defined $info->{default_value}) {
      $sql .= " DEFAULT '$info->{default_value}'";
    }
    return "$sql;";
  }
}

=method summary

=cut

sub summary {
  my ($self) = @_;
  my $prefix = $self->action eq 'add' ? '+'
             : $self->action eq 'drop' ? '-' : '~';
  my $type = $self->new_info ? " ($self->{new_info}{data_type})" : '';
  return sprintf '  %scolumn: %s.%s%s',
    $prefix, $self->table_name, $self->column_name, $type;
}

1;
