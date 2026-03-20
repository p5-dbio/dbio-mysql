use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;

my ($dsn, $user, $pass) = @ENV{map { "DBIOTEST_MYSQL_$_" } qw(DSN USER PASS)};

plan skip_all => 'Set DBIOTEST_MYSQL_DSN, _USER and _PASS to run this test'
    unless $dsn;

eval { require DBIO::Loader }
    or plan skip_all => 'DBIO::Loader required';

use DBI;

my $tmpdir = tempdir(CLEANUP => 1);

# Create test tables
my $dbh = DBI->connect($dsn, $user, $pass, { RaiseError => 1 });

# Clean up any previous test run
for my $t (qw(cd_tag track cd tag artist type_test)) {
    $dbh->do("DROP TABLE IF EXISTS dbio_loader_$t");
}

$dbh->do('CREATE TABLE dbio_loader_artist (
    id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    bio TEXT,
    UNIQUE KEY idx_name (name)
) ENGINE=InnoDB');

$dbh->do('CREATE TABLE dbio_loader_cd (
    id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
    artist_id INTEGER NOT NULL,
    title VARCHAR(256) NOT NULL,
    year INTEGER,
    FOREIGN KEY (artist_id) REFERENCES dbio_loader_artist(id)
) ENGINE=InnoDB');

$dbh->do('CREATE TABLE dbio_loader_track (
    id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
    cd_id INTEGER NOT NULL,
    title VARCHAR(256) NOT NULL,
    position INTEGER,
    FOREIGN KEY (cd_id) REFERENCES dbio_loader_cd(id)
) ENGINE=InnoDB');

$dbh->do('CREATE TABLE dbio_loader_tag (
    id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(64) NOT NULL
) ENGINE=InnoDB');

$dbh->do('CREATE TABLE dbio_loader_cd_tag (
    cd_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    PRIMARY KEY (cd_id, tag_id),
    FOREIGN KEY (cd_id) REFERENCES dbio_loader_cd(id),
    FOREIGN KEY (tag_id) REFERENCES dbio_loader_tag(id)
) ENGINE=InnoDB');

$dbh->do("CREATE TABLE dbio_loader_type_test (
    id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
    enum_col ENUM('foo','bar','baz'),
    set_col SET('a','b','c'),
    json_col JSON,
    ts_col TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dec_col DECIMAL(10,2),
    uint_col INTEGER UNSIGNED
) ENGINE=InnoDB");

$dbh->disconnect;

sub _slurp { open my $fh, '<', $_[0] or die "Cannot read $_[0]: $!"; local $/; <$fh> }

# --- Vanilla style ---

my $out_dir = File::Spec->catdir($tmpdir, 'vanilla');
mkdir $out_dir;

my $pid = fork();
die "fork: $!" unless defined $pid;
if (!$pid) {
    DBIO::Loader::make_schema_at('TestMySQL::Schema', {
        dump_directory => $out_dir,
        quiet          => 1,
        generate_pod   => 0,
        naming         => 'current',
        constraint     => qr/^dbio_loader_/,
    }, [$dsn, $user, $pass]);
    exit 0;
}
waitpid($pid, 0);
is($? >> 8, 0, 'Schema generated');

my $rd = "$out_dir/TestMySQL/Schema/Result";

# Tables detected
ok -f "$rd/DbioLoaderArtist.pm",   'artist table found';
ok -f "$rd/DbioLoaderCd.pm",       'cd table found';
ok -f "$rd/DbioLoaderTrack.pm",    'track table found';
ok -f "$rd/DbioLoaderTypeTest.pm", 'type_test table found';

# Column introspection
my $artist = _slurp("$rd/DbioLoaderArtist.pm");
like $artist, qr/is_auto_increment.*1/s,   'artist.id auto_increment';
like $artist, qr/data_type.*"varchar"/s,    'artist.name is varchar';

# FK and relationships
my $cd = _slurp("$rd/DbioLoaderCd.pm");
like $cd, qr/is_foreign_key.*1/s,          'cd.artist_id is FK';
like $cd, qr/belongs_to.*artist/s,         'cd belongs_to artist';
like $artist, qr/has_many/s,               'artist has_many';

# M2M
like $cd, qr/many_to_many/s,              'cd many_to_many via cd_tag';

# MySQL-specific types
my $types = _slurp("$rd/DbioLoaderTypeTest.pm");
like $types, qr/data_type.*"enum"/s,       'enum column detected';
like $types, qr/extra.*list.*foo/s,        'enum values introspected';
like $types, qr/data_type.*"set"/s,        'set column detected';
like $types, qr/data_type.*"json"/s,       'json column detected';
like $types, qr/is_auto_increment.*1/s,    'auto_increment detected';

# --- Cake style ---

my $cake_dir = File::Spec->catdir($tmpdir, 'cake');
mkdir $cake_dir;

$pid = fork();
die "fork: $!" unless defined $pid;
if (!$pid) {
    DBIO::Loader::make_schema_at('TestMySQL::Cake', {
        dump_directory => $cake_dir,
        quiet          => 1,
        generate_pod   => 0,
        naming         => 'current',
        loader_style   => 'cake',
        constraint     => qr/^dbio_loader_/,
    }, [$dsn, $user, $pass]);
    exit 0;
}
waitpid($pid, 0);
is($? >> 8, 0, 'Cake schema generated');

my $cake_rd = "$cake_dir/TestMySQL/Cake/Result";
my $cake_artist = _slurp("$cake_rd/DbioLoaderArtist.pm");
like $cake_artist, qr/use DBIO::Cake/,     'cake: uses DBIO::Cake';
like $cake_artist, qr/^col id => /m,       'cake: col DSL';

# Cleanup
$dbh = DBI->connect($dsn, $user, $pass, { RaiseError => 1 });
for my $t (qw(cd_tag track cd tag artist type_test)) {
    $dbh->do("DROP TABLE IF EXISTS dbio_loader_$t");
}
$dbh->disconnect;

done_testing;
