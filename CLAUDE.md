# CLAUDE.md — DBIO::MySQL

## Project Vision

MySQL and MariaDB specific schema management for DBIO (the DBIx::Class fork, see ../dbio/).

**Status**: Active development.

## Namespace

- `DBIO::MySQL` — MySQL schema component
- `DBIO::MySQL::MariaDB` — MariaDB schema component
- `DBIO::MySQL::Storage` — MySQL storage (replaces DBIO::Storage::DBI::mysql)
- `DBIO::MySQL::Storage::MariaDB` — MariaDB storage (replaces DBIO::Storage::DBI::MariaDB)

## Usage

```perl
# MySQL
package MyApp::DB;
use base 'DBIO::Schema';
__PACKAGE__->load_components('MySQL');

# MariaDB
package MyApp::DB;
use base 'DBIO::Schema';
__PACKAGE__->load_components('MySQL::MariaDB');
```

## Build System

Uses Dist::Zilla with `[@Author::GETTY]` plugin bundle.
