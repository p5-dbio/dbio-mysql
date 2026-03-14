# DBIO-MySQL

MySQL driver distribution for DBIO.

## Scope

- Provides MySQL storage behavior: `DBIO::MySQL::Storage`
- Provides MariaDB variants: `DBIO::MySQL::MariaDB`,
  `DBIO::MySQL::Storage::MariaDB`
- Provides MySQL SQLMaker: `DBIO::MySQL::SQLMaker`
- Owns MySQL-specific tests from the historical DBIx::Class monolithic test layout

## Migration Notes

- `DBIx::Class::Storage::DBI::mysql` -> `DBIO::MySQL::Storage`
- `DBIx::Class::Storage::DBI::MariaDB` -> `DBIO::MySQL::Storage::MariaDB`
- `DBIx::Class::SQLMaker::MySQL` -> `DBIO::MySQL::SQLMaker`

When installed, DBIO core can autodetect MySQL DSNs and load the storage
class through `DBIO::Storage::DBI` driver registration.

## Testing

Set environment variables for integration tests:

- `DBIOTEST_MYSQL_DSN`
- `DBIOTEST_MYSQL_USER`
- `DBIOTEST_MYSQL_PASS`

`t/20-sqlmaker-mysql.t` can run without a live database by using
`DBIO::Test` hybrid fake storage with
`storage_type => 'DBIO::MySQL::Storage'`.

Shared driver tests can also exercise the replicated core path with:

`DBIO::Test->init_schema(replicated => 1, storage_type => 'DBIO::MySQL::Storage')`
