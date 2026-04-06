---
name: dbio-core
description: "DBIO ORM architecture, API, component system, and coding conventions (DBIx::Class fork)"
user-invocable: false
allowed-tools: Read, Grep, Glob
model: sonnet
---

DBIO is a fork of DBIx::Class. When working in DBIO or any DBIO driver, use this knowledge.

## Key Differences from DBIx::Class

- Namespace: `DBIO::` not `DBIx::Class::`
- `DBIO::Core` replaces `DBIx::Class::Core`
- `DBIO::Schema` replaces `DBIx::Class::Schema`
- Uses `SQL::Abstract` (not `SQL::Abstract::Classic`)
- Integrates: `DBIx::Class::TimeStamp` → `DBIO::Timestamp`, `DBIx::Class::Helpers` → DBIO core
- SQL::Translator is OPTIONAL (only for legacy deploy) — being replaced by DB-specific modules

## Architecture

```
DBIO::Schema          — Database connection + ResultSource registry
  └── DBIO::ResultSource  — Table/view definition (columns, relationships, etc.)
       └── DBIO::ResultSet    — Query builder (search, filter, page)
            └── DBIO::Row         — Single row object (CRUD)

DBIO::Storage         — Abstract storage layer
  └── DBIO::Storage::DBI  — DBI-based storage (most databases)

DBIO::SQLMaker        — SQL generation (replaces SQL::Abstract integration)
```

## Component System

DBIO uses a component loading system via `load_components`:

```perl
package MyApp::DB;
use base 'DBIO::Schema';
__PACKAGE__->load_components('PostgreSQL');  # loads DBIO::PostgreSQL
```

Components are resolved relative to `DBIO::` namespace. A `+` prefix means absolute:

```perl
__PACKAGE__->load_components('+My::Custom::Component');
```

## Driver Architecture

Each database driver is a separate CPAN distribution:

| Distribution | Component | Storage Class |
|-------------|-----------|--------------|
| DBIO-PostgreSQL | `DBIO::PostgreSQL` | `DBIO::PostgreSQL::Storage` |
| DBIO-MySQL | `DBIO::MySQL` | `DBIO::MySQL::Storage` |
| DBIO-SQLite | `DBIO::SQLite` | `DBIO::SQLite::Storage` |
| DBIO-Replicated | — | `DBIO::Storage::DBI::Replicated` |

Driver components override `connection()` to set their storage type automatically.

## Result Class Pattern

```perl
package MyApp::DB::Result::User;
use base 'DBIO::Core';

__PACKAGE__->table('users');
__PACKAGE__->add_columns(
    id   => { data_type => 'integer', is_auto_increment => 1 },
    name => { data_type => 'varchar', size => 255 },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(posts => 'MyApp::DB::Result::Post', 'user_id');
```

## Relationship Types

- `belongs_to` — FK on this table
- `has_many` — FK on related table
- `has_one` — FK on related table, single result
- `many_to_many` — Through a bridge table
- `might_have` — Optional has_one

## ResultSet Chaining

```perl
my $rs = $schema->resultset('User')
    ->search({ active => 1 })
    ->search({ role => 'admin' })
    ->order_by('name');
```

## Testing

- `DBIO::Test` provides test utilities
- **Core tests MUST use `DBIO::Test::Storage` (fake storage)**, NEVER `dbi:SQLite` or any real DB
- Driver integration tests use env vars: `DBIOTEST_PG_DSN`, `TEST_DBIO_POSTGRESQL_DSN`, etc.
- Test files in `t/`, author tests in `xt/`
- **Shared test schemas** for cross-distribution features go in `DBIO::Test::Schema::*` under `dbio/lib/`
- Do NOT redefine result classes inline in driver tests — use the shared namespace

### Shared Test Schemas

| Schema | OO Layer | DDL | Description |
|--------|----------|-----|-------------|
| `DBIO::Test::Schema::Moo` | `DBIO::Moo` | `add_columns` | Moo result classes + Moo schema + custom ResultSet |
| `DBIO::Test::Schema::Moose` | `DBIO::Moose` | `add_columns` | Moose result classes + Moose schema + custom ResultSet |
| `DBIO::Test::Schema::MooCake` | `DBIO::Moo` + `DBIO::Cake` | Cake DDL | Moo + Cake combo |
| `DBIO::Test::Schema::MooseSugar` | `DBIO::Moose` + `DBIO::Cake` | Cake DDL | Moose + Cake combo |

Each schema has Artist + CD, a `has_many`/`belongs_to` relationship, one custom ResultSet (Artist) and one default (CD).

### Optional deps in tests

Skip the test if the dep is missing:
```perl
BEGIN { eval { require Moo; 1 } or plan skip_all => 'Moo not installed' }
```
List as `suggests` in cpanfile, never `requires`.

## OOP

- Core DBIO uses `Class::Accessor::Grouped` + `Class::C3::Componentised`
- Drivers may use `Moo` (e.g., PostgreSQL) or `Moose` (e.g., Replicated)
- No specific framework is required — match the existing driver's choice

## Moo / Moose Integration

`DBIO::Moo` and `DBIO::Moose` are optional bridge modules (`suggests` in cpanfile). See the dedicated `dbio-moo` and `dbio-moose` skills for full details on FOREIGNBUILDARGS, the lazy requirement, combining with Cake/Candy, Schema/ResultSet usage, and `make_immutable`.

## Copyright & Authorship

- Original: DBIx::Class & DBIO Contributors (see AUTHORS file)
- DBIO core copyright starts 2005 (original DBIx::Class)
- New driver distributions: Torsten Raudssus, copyright 2026
- Maintainer: Torsten Raudssus (GETTY on CPAN)
