---
name: perl-dzil-dbio
description: "Dist::Zilla and PodWeaver conventions for DBIO distributions ([@DBIO] bundle)"
user-invocable: false
allowed-tools: Read, Grep, Glob
model: sonnet
---

DBIO distributions use `[@DBIO]` from `Dist::Zilla::PluginBundle::DBIO`. NOT `[@Author::GETTY]`.

## dist.ini (drivers)

```ini
name = DBIO-DriverName
author = DBIO & DBIx::Class Authors
license = Perl_5

[@DBIO]
```

No version, no copyright_holder, no copyright_year. The bundle handles everything.

## dist.ini (DBIO core)

```ini
name = DBIO
author = DBIx::Class & DBIO Contributors (see AUTHORS file)
license = Perl_5
copyright_holder = DBIO Contributors
copyright_year = 2005

[@DBIO]
core = 1

[MetaResources]
; ...
```

`core = 1` changes: VersionFromMainModule, MakeMaker::Awesome, ExecDir, extra GatherDir excludes, no GithubMeta.

## Version Strategy

- **Drivers**: from git tags via `@Git::VersionManager` (first_version = 0.900000)
- **Core**: from `$VERSION` in lib/DBIO.pm via `[VersionFromMainModule]`
- 6-digit format: `0.900000`, target `1.000000` when stable

## PodWeaver (@DBIO config)

- `# ABSTRACT:` required on every .pm file
- `=attr name` after `has` -> collected into ATTRIBUTES section
- `=method name` after `sub` -> collected into METHODS section
- Never write NAME, VERSION, AUTHORS, COPYRIGHT (auto-generated)
- POD is inline, not at end of file
- Cross-refs: `L<DBIO::Module>`, never manual URLs

## Generated Copyright

```
Copyright (C) 2026 DBIO Authors
Portions Copyright (C) 2005-2025 DBIx::Class Authors
Based on DBIx::Class, heavily modified.
```

## Dependencies

In `cpanfile`, not dist.ini. Bundle uses `[Prereqs::FromCPANfile]`.

## Build & Test

```bash
dzil build && dzil test && dzil release
prove -l t/
prove -l -I../dbio/lib t/   # with local DBIO core
```
