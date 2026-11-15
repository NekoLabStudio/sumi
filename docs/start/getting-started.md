# Getting Started

Sumi turns a folder of Markdown files into a personal website. You write posts in plain text, preview them on your own machine and publish the result as a static site. This guide takes you from nothing to a working site.

In this guide you will learn:

- how to install the Sumi launcher
- how to create a site and preview it locally
- how to write your first post
- how to build the site and publish it

## Installing Sumi

Sumi runs on macOS and Linux. On macOS, install the launcher with Homebrew:

```bash
brew install nekolabstudio/tap/sumi
```

Homebrew keeps it up to date when you run `brew upgrade`.

On Linux, or if you don't use Homebrew, use the install script:

```bash
curl -fsSL https://oss.nekolab.studio/sumi/install.sh | sh
```

The script writes to `/usr/local/bin` by default. To install somewhere else, pass a directory:

```bash
curl -fsSL https://oss.nekolab.studio/sumi/install.sh | sh -s -- --dir "$HOME/.local/bin"
```

## Creating a site

With the launcher installed, create a site and start the local preview:

```bash
sumi init my-site
cd my-site
./sumi dev
```

During `init`, you choose where you want to publish, whether you want automated publishing, whether posts should syndicate to social media and whether you want to configure the Inkstead app connection. You can accept the defaults and add more later in `sumi.json`, the site's settings file.

Inside a site, use the `./sumi` wrapper rather than the global command; it keeps the site on the Sumi version recorded in `sumi.json`. See [the `./sumi` wrapper](commands.md#the-sumi-wrapper) for how it works.

![A starter Sumi website running locally.](/assets/getting-started-site.png)

## The starter content

Open the local URL printed by `./sumi dev`, then edit the starter content. It lives in a few folders:

- `content/posts` contains dated posts for your homepage and feeds.
- `content/pages` contains standalone pages like About or Now.
- `content/media` contains original photo files you want to keep with the site.
- `content/collections` can contain Markdown collections for structured content.

These are the default folders. You can change them in `sumi.json`; see [Site Configuration](site-configuration.md).

## Your first post

A post is a Markdown file with a small header called frontmatter, the block between the `---` lines. Create one in `content/posts`:

```md
---
title: Hello From My Website
date: 2026-05-10T18:30:00+01:00
---

This is my first Sumi post.
```

Run `./sumi dev` and the post appears on the homepage. Posts use dated permalinks by default, such as `/2026/05/10/hello-from-my-website/`.

You can also create posts from the command line. `./sumi new post` asks a couple of questions and writes the file with the right name and frontmatter.

See [Writing Posts](writing-posts.md) for everything posts can do.

## Local preview

While you write, keep the preview running:

```bash
./sumi dev
```

`dev` builds the site, serves it locally and watches for changes. When you save a post or template, the site rebuilds and open pages reload in the browser automatically.

To use a different port:

```bash
./sumi dev --port 8080
```

## Building the site

When you are ready to generate the static site:

```bash
./sumi build
```

The built site is written to `dist`. Everything in that folder is plain HTML, CSS and JavaScript, ready for any static host.

## Publishing

When you want the site online, and you chose a publishing target during `init`, publish with:

```bash
./sumi publish
```

`publish` builds the site, deploys it, syndicates any posts that ask to be syndicated, then updates the site again if new syndication links were added.

Before publishing from your own machine, copy the generated `.env.example` to `.env` and fill in the values. If you chose automated publishing, add the same names as CI secrets or variables instead.

> **Tip:** Run `./sumi doctor` before publishing. It reports anything missing; see [what doctor checks](commands.md#what-doctor-checks) for the full list.

See [Deployment](../deployment/index.md) for the publishing targets and what each one needs.
