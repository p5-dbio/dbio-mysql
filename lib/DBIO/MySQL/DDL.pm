package DBIO::MySQL::DDL;
# ABSTRACT: Generate MySQL/MariaDB DDL from DBIO Result classes
our $VERSION = '0.900000';

use strict;
use warnings;

=head1 DESCRIPTION

C<DBIO::MySQL::DDL> generates a MySQL DDL script from a L<DBIO::Schema>
class hierarchy. It is the desired-state side of the
test-deploy-and-compare strategy used by L<DBIO::MySQL::Deploy>.

    my $ddl = DBIO::MySQL::DDL->install_ddl($schema);

The generated DDL is plain SQL, one C<CREATE TABLE> per source. Tables
default to C<ENGINE=InnoDB> and C<CHARSET=utf8mb4 COLLATE
utf8mb4_unicode_ci>. Result classes can override per-table via
C<mysql_engine>, C<mysql_charset>, C<mysql_collate> attributes.

=cut

=method install_ddl

    my $ddl = DBIO::MySQL::DDL->install_ddl($schema);

Returns the full installation DDL as a single string.

=cut

sub install_ddl {
  my ($class, $schema) = @_;

  my @stmts;

  for my $source_name (sort $schema->sources) {
    my $source = $schema->source($source_name);
    my $result_class = $source->result_class;
    my $table_name   = $source->name;

    my @col_defs;
    my @pk_cols = $source->primary_columns;

    for my $col_name ($source->columns) {
      my $info = $source->column_info($col_name);
      my $type = _mysql_column_type($info);

      my $def = sprintf '  %s %s', _quote_ident($col_name), $type;
      $def .= ' NOT NULL' if defined $info->{is_nullable} && !$info->{is_nullable};
      $def .= ' AUTO_INCREMENT' if $info->{is_auto_increment};

      if (defined $info->{default_value}) {
        my $dv = $info->{default_value};
        if (ref $dv eq 'SCALAR') {
          $def .= " DEFAULT $$dv";
        } else {
          $def .= " DEFAULT '$dv'";
        }
      }

      push @col_defs, $def;
    }

    if (@pk_cols) {
      push @col_defs, sprintf '  PRIMARY KEY (%s)',
        join(', ', map { _quote_ident($_) } @pk_cols);
    }

    # Unique constraints
    if ($source->can('unique_constraints')) {
      my %uniques = $source->unique_constraints;
      for my $uname (sort keys %uniques) {
        next if $uname eq 'primary';
        my $cols = $uniques{$uname};
        push @col_defs, sprintf '  UNIQUE KEY %s (%s)',
          _quote_ident($uname),
          join(', ', map { _quote_ident($_) } @$cols);
      }
    }

    # Foreign keys derived from belongs_to relationships
    for my $rel ($source->relationships) {
      my $info = $source->relationship_info($rel);
      next unless $info && $info->{attrs} && $info->{attrs}{is_foreign_key_constraint};

      my $foreign = $info->{class};
      my $foreign_source = eval { $schema->source($foreign) }
        // eval { $schema->source($foreign =~ s/.*:://r) };
      next unless $foreign_source;

      my $cond = $info->{cond};
      next unless ref $cond eq 'HASH';

      my (@from, @to);
      for my $foreign_col (sort keys %$cond) {
        my $fcol = $foreign_col;
        $fcol =~ s/^foreign\.//;
        my $self_col = $cond->{$foreign_col};
        $self_col =~ s/^self\.//;
        push @to,   $fcol;
        push @from, $self_col;
      }

      push @col_defs, sprintf '  FOREIGN KEY (%s) REFERENCES %s(%s)',
        join(', ', map { _quote_ident($_) } @from),
        _quote_ident($foreign_source->name),
        join(', ', map { _quote_ident($_) } @to);
    }

    my $engine  = ($result_class->can('mysql_engine')  && $result_class->mysql_engine)  || 'InnoDB';
    my $charset = ($result_class->can('mysql_charset') && $result_class->mysql_charset) || 'utf8mb4';
    my $collate = ($result_class->can('mysql_collate') && $result_class->mysql_collate) || 'utf8mb4_unicode_ci';

    push @stmts, sprintf "CREATE TABLE %s (\n%s\n) ENGINE=%s DEFAULT CHARSET=%s COLLATE=%s;",
      _quote_ident($table_name),
      join(",\n", @col_defs),
      $engine, $charset, $collate;

    # MySQL-specific indexes via mysql_indexes (parallel to pg_indexes)
    if ($result_class->can('mysql_indexes')) {
      my $indexes = $result_class->mysql_indexes;
      for my $idx_name (sort keys %$indexes) {
        my $idx = $indexes->{$idx_name};
        my $unique = $idx->{unique} ? 'UNIQUE ' : '';
        my $type = $idx->{using} ? " USING $idx->{using}" : '';
        my $cols = join ', ',
          map { _quote_ident($_) } @{ $idx->{columns} // [] };
        push @stmts, sprintf 'CREATE %sINDEX %s ON %s (%s)%s;',
          $unique, _quote_ident($idx_name), _quote_ident($table_name), $cols, $type;
      }
    }
  }

  return join "\n\n", @stmts;
}

sub _mysql_column_type {
  my ($info) = @_;
  my $type = $info->{data_type} // 'text';

  # Pre-parameterized types pass through
  return $type if $type =~ /\(.+\)$/;

  # Use size for varchar/char
  if ($info->{size} && $type =~ /^(varchar|char|varbinary|binary)$/i) {
    return "$type($info->{size})";
  }

  my %type_map = (
    integer    => 'int',
    int        => 'int',
    bigint     => 'bigint',
    smallint   => 'smallint',
    tinyint    => 'tinyint',
    serial     => 'int',
    bigserial  => 'bigint',

    text       => 'text',
    varchar    => 'varchar(255)',
    char       => 'char(1)',
    string     => 'text',

    float      => 'float',
    real       => 'double',
    double     => 'double',
    'double precision' => 'double',
    numeric    => 'decimal(10,2)',
    decimal    => 'decimal(10,2)',
    boolean    => 'tinyint(1)',

    blob       => 'blob',
    bytea      => 'blob',

    date       => 'date',
    datetime   => 'datetime',
    timestamp  => 'timestamp',
    time       => 'time',
    json       => 'json',
  );

  return $type_map{ lc $type } // $type;
}

sub _quote_ident {
  my ($name) = @_;
  return "`$name`";
}

1;
