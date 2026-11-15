# Upgrading

Every Sumi release gets a page here. It lists whatever the release
needs from your site, with the fix for each: a changed command, a changed
configuration key, an edit only you can make. A release that needs nothing
says so.

## Updating a site

Sumi sites commit a small root `./sumi` command. It reads the version in `sumi.json` and downloads the matching release when needed. That keeps each site on the Sumi version it records.

The globally installed `sumi` command is mainly for creating sites and managing cached binaries. Inside a site, use `./sumi`.

To update a site to the latest Sumi release:

```bash
./sumi update
```

For CI or release-check scripts, `./sumi update --check` reports whether a newer release is available without changing files and exits with a non-zero status when the site is out of date. To preview the exact migration without writing changes, run:

```bash
./sumi update --dry-run
```

## Migrations

The `migrate` command compares the version recorded in `sumi.json` with the binary you are running. It applies needed migrations, refreshes generated workflow files and the site command, then updates the recorded version. Some releases do not need a site migration.

To apply migrations for the version already recorded in the site:

```bash
./sumi migrate
```

Then run:

```bash
./sumi doctor
./sumi build
```

If you use custom templates, check your theme against the current [Themes](/start/themes/) context values after major upgrades.

If Sumi reports a manual migration, finish that change and run `./sumi migrate` again. The recorded version is not advanced while a required manual step is still outstanding.

## The binary cache

To inspect or prune downloaded binaries:

```bash
./sumi cache list
./sumi cache clean --dry-run
./sumi cache clean
```

The cache defaults to `~/Library/Caches/sumi` on macOS and `${XDG_CACHE_HOME:-$HOME/.cache}/sumi` on Linux. Set `SUMI_CACHE_DIR` to use a different location.

## Versions

<!-- newest-first: prepare-release.sh inserts each release's line below -->
- [Sumi 2.4.0](/upgrading/2.4.0/)
- [Inkstead Writer 2.3.2](/upgrading/2.3.2/)
- [Inkstead Writer 2.3.1](/upgrading/2.3.1/)
- [Inkstead Writer 2.3.0](/upgrading/2.3.0/)
- [Inkstead Writer 2.2.1](/upgrading/2.2.1/)
