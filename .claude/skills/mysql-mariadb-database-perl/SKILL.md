---
name: mysql-mariadb-database-perl
description: "MySQL and MariaDB database knowledge for Perl driver development (DBD::mysql, storage engines, charset, MariaDB differences)"
user-invocable: false
allowed-tools: Read, Grep, Glob
model: sonnet
---

MySQL and MariaDB knowledge for Perl database driver development.

## DBD::mysql (Perl DBI Driver)

- `DBD::mysql` handles both MySQL and MariaDB connections
- Connection: `DBI->connect("dbi:mysql:database=mydb;host=localhost", $user, $pass)`
- `mysql_enable_utf8mb4 => 1` — essential for proper Unicode
- `mysql_auto_reconnect => 0` — disable in production (breaks transactions)

## MySQL vs MariaDB Key Differences

| Feature | MySQL | MariaDB |
|---------|-------|---------|
| JSON type | Native `JSON` | Alias for `LONGTEXT` (before 10.5) |
| CTEs | 8.0+ | 10.2+ (earlier support) |
| Window functions | 8.0+ | 10.2+ |
| Sequences | No | 10.3+ (`CREATE SEQUENCE`) |
| System versioning | No | 10.3+ (`WITH SYSTEM VERSIONING`) |
| CHECK constraints | Parsed but ignored (<8.0.16) | Enforced |
| Default storage engine | InnoDB | InnoDB (Aria for system tables) |
| `RETURNING` clause | No | 10.5+ |
| UUID type | No native type | `UUID` type (10.7+) |

Detection in Perl:

```perl
my $version = $dbh->selectrow_array("SELECT VERSION()");
my $is_mariadb = $version =~ /MariaDB/i;
```

## Storage Engines

| Engine | Use Case |
|--------|----------|
| **InnoDB** | Default. ACID, row-level locking, FK support |
| **MyISAM** | Legacy. Table-level locking, no transactions, no FK |
| **MEMORY** | Temporary data. Lost on restart |
| **Aria** | MariaDB only. Crash-safe MyISAM replacement |
| **ColumnStore** | MariaDB only. Analytical/OLAP workloads |

For DBIO driver: always assume InnoDB. MyISAM support is legacy.

## Character Sets and Collations

```sql
-- Connection level (critical!)
SET NAMES utf8mb4;

-- Table level
CREATE TABLE t (...) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- **Always use `utf8mb4`** — MySQL's `utf8` is broken (only 3 bytes, no emoji)
- Default collation: `utf8mb4_0900_ai_ci` (MySQL 8.0+) or `utf8mb4_unicode_ci`
- MariaDB uses `utf8mb4_general_ci` as default

## Type System

### Numeric

| Type | Size | Range |
|------|------|-------|
| `TINYINT` | 1 byte | -128 to 127 |
| `SMALLINT` | 2 bytes | -32768 to 32767 |
| `MEDIUMINT` | 3 bytes | ~8M |
| `INT` | 4 bytes | ~2B |
| `BIGINT` | 8 bytes | ~9.2E18 |
| `DECIMAL(M,D)` | Variable | Exact precision |
| `FLOAT` | 4 bytes | Approximate |
| `DOUBLE` | 8 bytes | Approximate |

### String

| Type | Max Length | Use Case |
|------|-----------|----------|
| `VARCHAR(N)` | 65,535 bytes | Variable-length strings |
| `TEXT` | 65,535 bytes | Long text |
| `MEDIUMTEXT` | 16 MB | Larger text |
| `LONGTEXT` | 4 GB | Very large text |
| `ENUM('a','b')` | 65,535 values | Fixed set of strings |
| `SET('a','b')` | 64 members | Multiple values from set |
| `JSON` | ~1 GB | JSON documents (MySQL 5.7+) |

### Date/Time

| Type | Format | Range |
|------|--------|-------|
| `DATE` | `YYYY-MM-DD` | 1000-01-01 to 9999-12-31 |
| `TIME` | `HH:MM:SS` | -838:59:59 to 838:59:59 |
| `DATETIME` | `YYYY-MM-DD HH:MM:SS` | 1000 to 9999 |
| `TIMESTAMP` | `YYYY-MM-DD HH:MM:SS` | 1970 to 2038 (UTC stored) |

## Auto-Increment

```sql
CREATE TABLE t (id INT AUTO_INCREMENT PRIMARY KEY);
INSERT INTO t (name) VALUES ('foo');
SELECT LAST_INSERT_ID();  -- returns the auto-increment value
```

- `LAST_INSERT_ID()` is per-connection (thread-safe)
- In Perl: `$dbh->last_insert_id(undef, undef, undef, undef)` or `$dbh->{mysql_insertid}`

## Transaction & Locking

- InnoDB: row-level locking, MVCC
- `START TRANSACTION` / `COMMIT` / `ROLLBACK`
- Savepoints: `SAVEPOINT sp1` / `ROLLBACK TO sp1` / `RELEASE SAVEPOINT sp1`
- `SELECT ... FOR UPDATE` — exclusive row lock
- `SELECT ... LOCK IN SHARE MODE` — shared row lock
- Deadlock detection: InnoDB auto-detects, rolls back one transaction

## LIMIT/OFFSET

```sql
SELECT * FROM t LIMIT 10 OFFSET 20;
-- or
SELECT * FROM t LIMIT 20, 10;  -- offset, count (MySQL-specific order!)
```

## Testing with MySQL/MariaDB

- Integration tests: `DBIOTEST_MYSQL_DSN`, `DBIOTEST_MYSQL_USER`, `DBIOTEST_MYSQL_PASS`
- Docker: `docker run -d -e MYSQL_ROOT_PASSWORD=test -p 3306:3306 mysql:8`
- MariaDB: `docker run -d -e MARIADB_ROOT_PASSWORD=test -p 3306:3306 mariadb:11`
