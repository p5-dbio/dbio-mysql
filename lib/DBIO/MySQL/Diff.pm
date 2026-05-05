package DBIO::MySQL::Diff;
# ABSTRACT: Compare two introspected MySQL/MariaDB models
our $VERSION = '0.900000';

use strict;
use warnings;

use base 'DBIO::Diff::Base';

use DBIO::MySQL::Diff::Table;
use DBIO::MySQL::Diff::Column;
use DBIO::MySQL::Diff::Index;
use DBIO::MySQL::Diff::ForeignKey;

=head1 DESCRIPTION

C<DBIO::MySQL::Diff> compares two introspected MySQL/MariaDB models
(as produced by L<DBIO::MySQL::Introspect>) and produces a list of
structured diff operations.

    my $diff = DBIO::MySQL::Diff->new(
        source => $current_model,
        target => $desired_model,
    );

    if ($diff->has_changes) {
        print $diff->as_sql;
        print $diff->summary;
    }

Operations are emitted in dependency order: tables, columns, indexes,
foreign keys.

=cut

sub _build_operations {
  my ($self) = @_;
  my @ops;

  push @ops, DBIO::MySQL::Diff::Table->diff(
    $self->source->{tables}, $self->target->{tables},
    $self->target->{columns}, $self->target->{foreign_keys},
  );
  push @ops, DBIO::MySQL::Diff::Column->diff(
    $self->source->{columns}, $self->target->{columns},
    $self->source->{tables},  $self->target->{tables},
  );
  push @ops, DBIO::MySQL::Diff::Index->diff(
    $self->source->{indexes}, $self->target->{indexes},
  );
  push @ops, DBIO::MySQL::Diff::ForeignKey->diff(
    $self->source->{foreign_keys}, $self->target->{foreign_keys},
    $self->source->{tables},       $self->target->{tables},
  );

  return \@ops;
}

1;
