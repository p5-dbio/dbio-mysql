# CLAUDE.md — DBIO::MySQL

## Namespace

- `DBIO::MySQL` — MySQL schema component
- `DBIO::MySQL::MariaDB` — MariaDB schema component
- `DBIO::MySQL::Storage` — MySQL storage
- `DBIO::MySQL::Storage::MariaDB` — MariaDB storage

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
