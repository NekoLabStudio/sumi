# Sumi for Nova

Adds Nova support for Sumi templates:

- `.sumi` syntax detection and highlighting.
- Indentation and bracket rules for Sumi blocks.
- Diagnostics, completions, document symbols and formatting through `sumi theme language-server`.
- Extension commands for restarting the language server, running `sumi theme check`, and the site's dev server, build, deploy, migrate and doctor.

The extension uses the site's `./sumi` launcher when there is one, then `sumi` on `PATH`. Set `sumi.toolPath` to point at a specific binary.

Release builds are published as zipped `.novaextension` bundles on the Sumi GitHub release.
