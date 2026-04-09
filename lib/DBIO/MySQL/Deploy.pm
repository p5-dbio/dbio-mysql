package DBIO::MySQL::Deploy;
# ABSTRACT: Deploy and upgrade MySQL/MariaDB schemas via test-deploy-and-compare
our $VERSION = '0.900000';

use strict;
use warnings;

use DBI;
use DBIO::MySQL::DDL;
use DBIO::MySQL::Introspect;
use DBIO::MySQL::Diff;

=head1 DESCRIPTION

C<DBIO::MySQL::Deploy> orchestrates the deployment and upgrade of
MySQL/MariaDB schemas using a test-deploy-and-compare strategy parallel
to L<DBIO::PostgreSQL::Deploy>.

For upgrades, instead of computing diffs from abstract class
representations, it:

=over 4

=item 1. Introspects the live database via C<information_schema>

=item 2. Creates a temporary database (C<CREATE DATABASE>)

=item 3. Deploys the desired schema (from DBIO classes) into the temp database

=item 4. Introspects the temp database the same way

=item 5. Computes the diff between the two models using L<DBIO::MySQL::Diff>

=item 6. Drops the temp database

=back

    my $deploy = DBIO::MySQL::Deploy->new(
        schema => MyApp::DB->connect($dsn, $user, $pass),
    );

    $deploy->install;     # fresh install
    $deploy->upgrade;     # diff + apply

=cut

sub new {
  my ($class, %args) = @_;
  $args{temp_db_prefix} //= '_dbio_tmp_';
  bless \%args, $class;
}

sub schema         { $_[0]->{schema} }
sub temp_db_prefix { $_[0]->{temp_db_prefix} }

=attr schema

A connected L<DBIO::Schema> instance using L<DBIO::MySQL>. Required.

=cut

=attr temp_db_prefix

Prefix for temporary databases created during C<diff>. Defaults to
C<_dbio_tmp_>. The full name includes the PID and current timestamp.

=cut

=method install

=cut

sub install {
  my ($self) = @_;
  my $ddl = DBIO::MySQL::DDL->install_ddl($self->schema);
  my $dbh = $self->_dbh;
  for my $stmt (_split_statements($ddl)) {
    $dbh->do($stmt);
  }
  return 1;
}

=method diff

=cut

sub diff {
  my ($self) = @_;

  my $dbh     = $self->_dbh;
  my $temp_db = $self->_create_temp_db($dbh);

  my $source_model = eval { DBIO::MySQL::Introspect->new(dbh => $dbh)->model };
  my $err_source   = $@;

  my $target_model = eval { $self->_deploy_and_introspect_temp($temp_db) };
  my $err_target   = $@;

  eval { $self->_drop_temp_db($dbh, $temp_db) };

  die $err_source if $err_source;
  die $err_target if $err_target;

  return DBIO::MySQL::Diff->new(
    source => $source_model,
    target => $target_model,
  );
}

=method apply

=cut

sub apply {
  my ($self, $diff) = @_;
  return unless $diff->has_changes;

  my $dbh = $self->_dbh;
  for my $stmt (_split_statements($diff->as_sql)) {
    next if $stmt =~ /^\s*--/;
    $dbh->do($stmt);
  }
  return 1;
}

=method upgrade

=cut

sub upgrade {
  my ($self) = @_;
  my $diff = $self->diff;
  return unless $diff->has_changes;
  $self->apply($diff);
  return $diff;
}

# --- Internal ---

sub _dbh { $_[0]->schema->storage->dbh }

sub _create_temp_db {
  my ($self, $dbh) = @_;
  my $name = $self->temp_db_prefix . $$ . '_' . time();
  $dbh->do(sprintf 'CREATE DATABASE `%s`', $name);
  return $name;
}

sub _drop_temp_db {
  my ($self, $dbh, $name) = @_;
  $dbh->do(sprintf 'DROP DATABASE IF EXISTS `%s`', $name);
}

sub _deploy_and_introspect_temp {
  my ($self, $temp_db) = @_;

  my ($dsn, $user, $pass) = $self->_temp_connect_info($temp_db);
  my $temp_dbh = DBI->connect($dsn, $user, $pass, {
    RaiseError => 1, PrintError => 0, AutoCommit => 1,
  }) or die "Cannot connect to temp database: $DBI::errstr";

  eval {
    my $ddl = DBIO::MySQL::DDL->install_ddl($self->schema);
    for my $stmt (_split_statements($ddl)) {
      $temp_dbh->do($stmt);
    }
  };
  my $err = $@;

  my $model;
  unless ($err) {
    eval {
      $model = DBIO::MySQL::Introspect->new(dbh => $temp_dbh)->model;
    };
    $err = $@ unless $model;
  }

  $temp_dbh->disconnect;
  die $err if $err;
  return $model;
}

sub _temp_connect_info {
  my ($self, $temp_db) = @_;
  my $storage = $self->schema->storage;
  my @info    = @{ $storage->connect_info };
  my ($dsn, $user, $pass) = @info;

  if (ref $dsn eq 'CODE') {
    die "DBIO::MySQL::Deploy does not support coderef DSN";
  }

  if ($dsn =~ /(?:database|dbname)=/i) {
    $dsn =~ s/(database|dbname)=[^;]+/$1=$temp_db/i;
  } else {
    $dsn .= ";database=$temp_db";
  }

  return ($dsn, $user, $pass);
}

sub _split_statements {
  my ($sql) = @_;
  my @stmts;
  my $current = '';

  for my $line (split /\n/, $sql) {
    $current .= "$line\n";
    if ($line =~ /;\s*$/) {
      $current =~ s/^\s+|\s+$//g;
      push @stmts, $current if $current =~ /\S/;
      $current = '';
    }
  }
  $current =~ s/^\s+|\s+$//g;
  push @stmts, $current if $current =~ /\S/;

  return @stmts;
}

=seealso

=over 4

=item * L<DBIO::MySQL>

=item * L<DBIO::MySQL::DDL>

=item * L<DBIO::MySQL::Introspect>

=item * L<DBIO::MySQL::Diff>

=item * L<DBIO::PostgreSQL::Deploy> - the PostgreSQL counterpart

=item * L<DBIO::SQLite::Deploy> - the SQLite counterpart

=back

=cut

1;
