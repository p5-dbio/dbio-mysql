package DBIO::MySQL::Loader;
# ABSTRACT: MySQL introspection for DBIO::Loader
our $VERSION = '0.900000';

use strict;
use warnings;
use base 'DBIO::Loader::DBI';
use mro 'c3';
use Carp::Clan qw/^DBIO/;
use List::Util qw/any first/;
use Try::Tiny;
use Scalar::Util 'blessed';
use DBIO::Loader::Utils qw/sigwarn_silencer/;
use namespace::clean;
use DBIO::Loader::Table ();

=head1 DESCRIPTION

This is the MySQL-specific Loader implementation used by L<DBIO::Loader> when
it detects a MySQL backend. It extends the generic DBI loader with
MySQL-aware introspection for foreign keys, unique constraints, column types,
and schema enumeration.

For the public loader interface, see L<DBIO::Loader> and
L<DBIO::Loader::Base>.

=cut

sub _setup {
    my $self = shift;

    $self->schema->storage->sql_maker->quote_char("`");
    $self->schema->storage->sql_maker->name_sep(".");

    $self->next::method(@_);

    if (not defined $self->preserve_case) {
        $self->preserve_case(0);
    }

    if ($self->db_schema && $self->db_schema->[0] eq '%') {
        my @schemas = try {
            $self->_show_databases;
        }
        catch {
            croak "no SHOW DATABASES privileges: $_";
        };

        @schemas = grep {
            my $schema = $_;
            not any { lc($schema) eq lc($_) } $self->_system_schemas
        } @schemas;

        $self->db_schema(\@schemas);
    }
}

# DBD::mysql uses mysql_* attributes; DBD::MariaDB uses mariadb_* attributes.
sub _dbd_attr_prefix {
    my ($self) = @_;
    return $self->dbh->{Driver}{Name} eq 'MariaDB' ? 'mariadb' : 'mysql';
}

sub _show_databases {
    my $self = shift;

    return map $_->[0], @{ $self->dbh->selectall_arrayref('SHOW DATABASES') };
}

sub _system_schemas {
    my $self = shift;

    return ($self->next::method(@_), 'mysql');
}

sub _table_fk_info {
    my ($self, $table) = @_;

    my $table_def_ref = eval { $self->dbh->selectrow_arrayref("SHOW CREATE TABLE ".$table->sql_name) };
    my $table_def = $table_def_ref->[1];

    return [] if not $table_def;

    my $qt  = qr/["`]/;
    my $nqt = qr/[^"`]/;

    my (@reldata) = ($table_def =~
        /CONSTRAINT ${qt}${nqt}+${qt} FOREIGN KEY \($qt(.*)$qt\) REFERENCES (?:$qt($nqt+)$qt\.)?$qt($nqt+)$qt \($qt(.+)$qt\)\s*(.*)/ig
    );

    my @rels;
    while (scalar @reldata > 0) {
        my ($cols, $f_schema, $f_table, $f_cols, $rest) = splice @reldata, 0, 5;

        my @cols   = map { s/$qt//g; $self->_lc($_) }
            split(/$qt?\s*$qt?,$qt?\s*$qt?/, $cols);

        my @f_cols = map { s/$qt//g; $self->_lc($_) }
            split(/$qt?\s*$qt?,$qt?\s*$qt?/, $f_cols);

        # Match case of remote schema to that in SHOW DATABASES, if it's there
        # and we have permissions to run SHOW DATABASES.
        if ($f_schema) {
            my $matched = first {
                lc($_) eq lc($f_schema)
            } try { $self->_show_databases };

            $f_schema = $matched if $matched;
        }

        my $remote_table = do {
            # Get ->tables_list to return tables from the remote schema, in case it is not in the db_schema list.
            local $self->{db_schema} = [ $f_schema ] if $f_schema;

            first {
                lc($_->name) eq lc($f_table)
                && ((not $f_schema) || lc($_->schema) eq lc($f_schema))
            } $self->_tables_list;
        };

        # The table may not be in any database, or it may not have been found by the previous code block for whatever reason.
        if (not $remote_table) {
            my $remote_schema = $f_schema || $self->db_schema && @{ $self->db_schema } == 1 && $self->db_schema->[0];

            $remote_table = DBIO::Loader::Table->new(
                loader => $self,
                name   => $f_table,
                ($remote_schema ? (
                    schema => $remote_schema,
                ) : ()),
            );
        }

        my %attrs;

        if ($rest) {
            my @on_clauses = $rest =~ /(ON DELETE|ON UPDATE) (RESTRICT|CASCADE|SET NULL|NO ACTION) ?/ig;

            while (my ($clause, $value) = splice @on_clauses, 0, 2) {
                $clause = lc $clause;
                $clause =~ s/ /_/;

                $value = uc $value;

                $attrs{$clause} = $value;
            }
        }

# The default behavior is RESTRICT. Specifying RESTRICT explicitly just removes
# that ON clause from the SHOW CREATE TABLE output. For this reason, even
# though the default for these clauses everywhere else in Schema::Loader is
# CASCADE, we change the default here to RESTRICT in order to reproduce the
# schema faithfully.
        $attrs{on_delete}     ||= 'RESTRICT';
        $attrs{on_update}     ||= 'RESTRICT';

# MySQL does not have a DEFERRABLE attribute, but there is a way to defer FKs.
        $attrs{is_deferrable}   = 1;

        push(@rels, {
            local_columns => \@cols,
            remote_columns => \@f_cols,
            remote_table => $remote_table,
            attrs => \%attrs,
        });
    }

    return \@rels;
}

# primary and unique info comes from the same sql statement,
#   so cache it here for both routines to use
sub _mysql_table_get_keys {
    my ($self, $table) = @_;

    if(!exists($self->{_cache}->{_mysql_keys}->{$table->sql_name})) {
        my %keydata;
        my $sth = $self->dbh->prepare('SHOW INDEX FROM '.$table->sql_name);
        $sth->execute;
        while(my $row = $sth->fetchrow_hashref) {
            next if $row->{Non_unique};
            push(@{$keydata{$row->{Key_name}}},
                [ $row->{Seq_in_index}, $self->_lc($row->{Column_name}) ]
            );
        }
        foreach my $keyname (keys %keydata) {
            my @ordered_cols = map { $_->[1] } sort { $a->[0] <=> $b->[0] }
                @{$keydata{$keyname}};
            $keydata{$keyname} = \@ordered_cols;
        }
        $self->{_cache}->{_mysql_keys}->{$table->sql_name} = \%keydata;
    }

    return $self->{_cache}->{_mysql_keys}->{$table->sql_name};
}

sub _table_pk_info {
    my ( $self, $table ) = @_;

    return $self->_mysql_table_get_keys($table)->{PRIMARY};
}

sub _table_uniq_info {
    my ( $self, $table ) = @_;

    my @uniqs;
    my $keydata = $self->_mysql_table_get_keys($table);
    foreach my $keyname (sort keys %$keydata) {
        next if $keyname eq 'PRIMARY';
        push(@uniqs, [ $keyname => $keydata->{$keyname} ]);
    }

    return \@uniqs;
}

sub _columns_info_for {
    my $self = shift;
    my ($table) = @_;

    my $result = $self->next::method(@_);

    while (my ($col, $info) = each %$result) {
        if ($info->{data_type} eq 'int') {
            $info->{data_type} = 'integer';
        }
        elsif ($info->{data_type} eq 'double') {
            $info->{data_type} = 'double precision';
        }
        elsif ($info->{data_type} =~ /^(point|linestring|polygon|multipoint|multilinestring|multipolygon|geometry|geometrycollection)\z/i) {
            $info->{data_type} = lc($info->{data_type});
            $info->{extra}{mysql_spatial} = 1;
        }
        my $data_type = $info->{data_type};

        delete $info->{size} if $data_type !~ /^(?: (?:var)?(?:char(?:acter)?|binary) | bit | year)\z/ix;

        # information_schema is available in 5.0+
        my ($precision, $scale, $column_type, $default) = eval { $self->dbh->selectrow_array(<<'EOF', {}, $table->name, lc($col)) };
SELECT numeric_precision, numeric_scale, column_type, column_default
FROM information_schema.columns
WHERE table_schema = schema() AND table_name = ? AND lower(column_name) = ?
EOF
        my $has_information_schema = not $@;

        $column_type = '' if not defined $column_type;

        if ($data_type eq 'bit' && (not exists $info->{size})) {
            $info->{size} = $precision if defined $precision;
        }
        elsif ($data_type =~ /^(?:float|double precision|decimal)\z/i) {
            if (defined $precision && defined $scale) {
                if ($precision == 10 && $scale == 0) {
                    delete $info->{size};
                }
                else {
                    $info->{size} = [$precision,$scale];
                }
            }
        }
        elsif ($data_type eq 'year') {
            if ($column_type =~ /\(2\)/) {
                $info->{size} = 2;
            }
            elsif ($column_type =~ /\(4\)/ || $info->{size} == 4) {
                delete $info->{size};
            }
        }
        elsif ($data_type =~ /^(?:date(?:time)?|timestamp)\z/) {
            if (not (defined $self->datetime_undef_if_invalid && $self->datetime_undef_if_invalid == 0)) {
                $info->{datetime_undef_if_invalid} = 1;
            }
        }
        # MariaDB reports spatial types as varchar — correct using column_type
        elsif ($column_type =~ /^(point|linestring|polygon|multipoint|multilinestring|multipolygon|geometry(?:collection)?)\z/i) {
            $info->{data_type} = lc($1);
            $info->{extra}{mysql_spatial} = 1;
            delete $info->{size};
            delete $info->{is_auto_increment};
        }
        elsif ($data_type =~ /^(?:enum|set)\z/ && $has_information_schema
               && $column_type =~ /^(?:enum|set)\(/) {

            delete $info->{extra}{list};

            while ($column_type =~ /'((?:[^']* (?:''|\\')* [^']*)* [^\\']?)',?/xg) {
                my $el = $1;
                $el =~ s/''/'/g;
                push @{ $info->{extra}{list} }, $el;
            }
        }

        # Sometimes apparently there's a bug where default_value gets set to ''
        # for things that don't actually have or support that default (like ints.)
        if (exists $info->{default_value} && $info->{default_value} eq '') {
            if ($has_information_schema) {
                if (not defined $default) {
                    delete $info->{default_value};
                }
            }
            else { # just check if it's a char/text type, otherwise remove
                delete $info->{default_value} unless $data_type =~ /char|text/i;
            }
        }
    }

    # Column-level charset and collation
    my $charset_sth = eval { $self->dbh->prepare(
        q{SELECT column_name, character_set_name, collation_name
          FROM information_schema.columns
          WHERE table_schema = schema() AND table_name = ?
            AND character_set_name IS NOT NULL}
    ) };
    if ($charset_sth) {
        $charset_sth->execute($table->name);
        while (my $row = $charset_sth->fetchrow_hashref) {
            my $col_name = $self->_lc($row->{column_name} // $row->{COLUMN_NAME});
            next unless exists $result->{$col_name};
            my $charset   = $row->{character_set_name} // $row->{CHARACTER_SET_NAME};
            my $collation = $row->{collation_name}      // $row->{COLLATION_NAME};
            $result->{$col_name}{extra}{mysql_charset}   = $charset   if $charset;
            $result->{$col_name}{extra}{mysql_collation} = $collation if $collation;

            # MariaDB has no native JSON type — it stores JSON as longtext with
            # utf8mb4_bin collation.  Remap to data_type => 'json'.
            if (   $self->_dbd_attr_prefix eq 'mariadb'
                && ($result->{$col_name}{data_type} // '') eq 'longtext'
                && ($collation // '') eq 'utf8mb4_bin' ) {
                $result->{$col_name}{data_type} = 'json';
                delete $result->{$col_name}{extra}{mysql_charset};
                delete $result->{$col_name}{extra}{mysql_collation};
            }
        }
    }

    # Virtual/generated columns (MySQL 5.7+, MariaDB 10.2+)
    my $gen_sth = eval { $self->dbh->prepare(
        q{SELECT column_name, generation_expression, extra
          FROM information_schema.columns
          WHERE table_schema = schema() AND table_name = ?
            AND generation_expression IS NOT NULL
            AND generation_expression != ''}
    ) };
    if ($gen_sth) {
        $gen_sth->execute($table->name);
        while (my $row = $gen_sth->fetchrow_hashref) {
            my $col_name = $self->_lc($row->{column_name} // $row->{COLUMN_NAME});
            next unless exists $result->{$col_name};
            my $extra_str = lc($row->{extra} // $row->{EXTRA} // '');
            my $kind = $extra_str =~ /stored/i ? 'stored' : 'virtual';
            $result->{$col_name}{extra}{generated} = $kind;
            $result->{$col_name}{extra}{generation_expression} =
                $row->{generation_expression} // $row->{GENERATION_EXPRESSION};
        }
    }

    return $result;
}

sub _extra_column_info {
    no warnings 'uninitialized';
    my ($self, $table, $col, $info, $dbi_info) = @_;
    my %extra_info;
    my $p = $self->_dbd_attr_prefix;

    # DBD::mysql and DBD::MariaDB throw on unknown sth attributes, so use eval
    my $is_auto_inc = eval { $dbi_info->{"${p}_is_auto_increment"} };
    my $type_name   = eval { $dbi_info->{"${p}_type_name"} } // '';
    my $values      = eval { $dbi_info->{"${p}_values"} };

    if ($is_auto_inc) {
        $extra_info{is_auto_increment} = 1;
    }
    if ($type_name =~ /\bunsigned\b/i) {
        $extra_info{extra}{unsigned} = 1;
    }
    if ($values) {
        $extra_info{extra}{list} = $values;
    }
    if ((not blessed $dbi_info) # isa $sth
        && lc($dbi_info->{COLUMN_DEF}) eq 'current_timestamp'
        && lc($type_name)              eq 'timestamp') {

        my $current_timestamp = 'current_timestamp';
        $extra_info{default_value} = \$current_timestamp;
    }
    if ((not blessed $dbi_info)
        && $type_name =~ /on update current_timestamp/i) {
        $extra_info{extra}{on_update_current_timestamp} = 1;
    }

    return \%extra_info;
}

sub _setup_src_meta {
    my ($self, $table) = @_;
    $self->next::method($table);

    my $table_class = $self->classes->{$table->sql_name};

    # Engine type and table collation
    my $table_meta = try {
        my ($engine, $collation) = $self->dbh->selectrow_array(
            q{SELECT engine, table_collation
              FROM information_schema.tables
              WHERE table_schema = schema() AND table_name = ?},
            undef, $table->name,
        );
        my %meta;
        $meta{mysql_engine}    = $engine    if $engine;
        $meta{mysql_collation} = $collation if $collation;
        \%meta;
    };

    if ($table_meta && %$table_meta) {
        $self->_dbic_stmt(
            $table_class,
            'result_source_instance->source_info',
            $table_meta,
        );
    }
}

sub _dbh_column_info {
    my $self = shift;

    local $SIG{__WARN__} = sigwarn_silencer(
        qr/^column_info: unrecognized column type/
    );

    $self->next::method(@_);
}

sub _table_comment {
    my ( $self, $table ) = @_;
    my $comment = $self->next::method($table);
    if (not $comment) {
        ($comment) = try { $self->schema->storage->dbh->selectrow_array(
            qq{SELECT table_comment
                FROM information_schema.tables
                WHERE table_schema = schema()
                  AND table_name = ?
            }, undef, $table->name);
        };
        # InnoDB likes to auto-append crap.
        if (not $comment) {
            # Do nothing.
        }
        elsif ($comment =~ /^InnoDB free:/) {
            $comment = undef;
        }
        else {
            $comment =~ s/; InnoDB.*//;
        }
    }
    return $comment;
}

sub _column_comment {
    my ( $self, $table, $column_number, $column_name ) = @_;
    my $comment = $self->next::method($table, $column_number, $column_name);
    if (not $comment) {
        ($comment) = try { $self->schema->storage->dbh->selectrow_array(
            qq{SELECT column_comment
                FROM information_schema.columns
                WHERE table_schema = schema()
                  AND table_name = ?
                  AND lower(column_name) = ?
            }, undef, $table->name, lc($column_name));
        };
    }
    return $comment;
}

sub _view_definition {
    my ($self, $view) = @_;

    return scalar $self->schema->storage->dbh->selectrow_array(
        q{SELECT view_definition
            FROM information_schema.views
           WHERE table_schema = schema()
             AND table_name = ?
        }, undef, $view->name,
    );
}

=head1 SEE ALSO

L<DBIO::Loader>, L<DBIO::Loader::Base>,
L<DBIO::Loader::DBI>

=cut

1;
# vim:et sw=4 sts=4 tw=0:
