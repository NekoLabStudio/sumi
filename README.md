# Sumi

Sumi is an opinionated publishing engine for personal indie websites. Write in Markdown, build a static site, deploy anywhere, and optionally syndicate posts to social media.

Sumi supports macOS and Linux.

## Get Started

Install the `sumi` launcher. On macOS, use Homebrew:

```bash
brew install nekolabstudio/tap/sumi
```

On Linux, or without Homebrew, use the install script:

```bash
curl -fsSL https://oss.nekolab.studio/sumi/install.sh | sh
```

Then create and preview a site:

```bash
sumi init my-site
cd my-site
./sumi doctor
./sumi dev
```

The full documentation is available at [oss.nekolab.studio/sumi](https://oss.nekolab.studio/sumi).

Inside a site, use the generated `./sumi` command. It keeps that site on the Sumi version recorded in `sumi.json`. Use `sumi init --help` to see options for publishing, CI, syndication, and Inkstead app setup.

## Templates

Sumi themes are written in Sumi's own templating language, which brings HTML, styles, assets, and behaviour into one authoring model. Theme commands run through `./sumi theme ...`.
