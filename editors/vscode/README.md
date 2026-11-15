# Sumi for VS Code

Adds editor support for Sumi templates:

- Syntax highlighting for `.sumi` files.
- Snippets for common directives and components.
- Formatting, diagnostics, completions and document symbols through `sumi theme language-server`.
- A `Sumi: Check Templates` command that runs `sumi theme check`.
- Commands for the site's dev server, build, deploy, migrate and doctor.

The extension uses the site's `./sumi` launcher when there is one, then `sumi` on `PATH`. Set `sumi.toolPath` to point at a specific binary.

Release builds are published as `.vsix` files on the Sumi GitHub release.
