# DBIO::MySQL::Loader TODO

Ported from DBIx::Class::Schema::Loader::DBI::mysql. Lives at `DBIO::MySQL::Loader`.

## Integration

- [ ] Test with real MySQL/MariaDB database (needs DBIOTEST_MYSQL_DSN)
- [ ] Merge with existing dbio-mysql introspection if any

## MySQL/MariaDB-Specific Improvements

- [ ] Introspect engine type (InnoDB, MyISAM, etc.) as table metadata
- [ ] Introspect charset/collation per table and column
- [ ] Introspect virtual/generated columns
- [ ] Support MariaDB-specific types (e.g. UUID in MariaDB 10.7+)
- [ ] Introspect JSON columns properly (MySQL 5.7+ / MariaDB 10.2+)
- [ ] Handle unsigned integer columns → generate `unsigned` modifier in Cake
- [ ] Handle ON UPDATE CURRENT_TIMESTAMP
- [ ] Introspect spatial types (POINT, POLYGON, etc.)

## Testing

- [ ] Port MySQL-specific loader tests from Schema::Loader
- [ ] Test with both MySQL and MariaDB
- [ ] Test charset-aware column introspection
- [ ] Test Cake/Candy output format for MySQL-specific types
