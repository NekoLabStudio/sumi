# Themes

Sumi ships with a default theme, so a new site looks finished from day one. When you want your own design, you replace parts of the theme with `.sumi` template files, and anything you do not replace keeps using the default.

Themes are written in Sumi templates. This page focuses on how Sumi loads themes and what data it passes to them. The template language has guides of its own: [Syntax](../templates/syntax.md), [Filters](../templates/filters.md), [Components](../templates/components.md), [Resources](../templates/resources.md), [Behaviour](../templates/behaviour.md) and [Client scripts](../templates/client-scripts.md).

In this guide you will learn:

- how to start from the default theme and override parts of it
- which page templates Sumi looks for and what data they receive
- how assets, images, styles and scripts work in templates
- how to customise feeds and layouts

## Starting from the default theme

The easiest way to learn the theme structure is to copy the default templates into your site:

```bash
./sumi theme eject
```

Existing files are left alone. Use `--force` if you want to overwrite them.

You do not need to eject everything to customise a site. Any file you add under `theme` overrides the matching built-in file, and missing files continue to use the default theme.

## Theme folder

The recommended shape is:

```txt
theme/
  layouts/
    default.sumi
  pages/
    404.sumi
    home.sumi
    category.sumi
    post.sumi
    page.sumi
    feed.xml.sumi
    feed.json.sumi
  components/
    PostCard.sumi
  styles/
    site.css
  scripts/
    site.sumi
```

If you want to keep themes somewhere else, set `theme.path` in [Site Configuration](site-configuration.md).

## Page templates

Sumi looks for these page templates under `theme/pages`:

- `404.sumi` for the not-found page written to `/404.html`.
- `home.sumi` for the homepage.
- `category.sumi` for category indexes.
- `post.sumi` for posts.
- `page.sumi` for standalone pages.
- `feed.xml.sumi` for RSS feeds.
- `feed.json.sumi` for JSON Feed.

Standalone pages can also use slug-specific templates. For example, `content/pages/photos.md` normally renders with `page.sumi`, but `theme/pages/photos.sumi` takes over that page when it exists:

```txt
content/pages/photos.md
theme/pages/photos.sumi
```

```sumi
<h1>{page.title}</h1>

<div class="photo-grid">
  @for post in photoPosts {
    <a href="{post.urlPath}">
      @image(post.firstImage, alt: post.alt | default(""))
    </a>
  }
</div>
```

The not-found page receives a `notFound` object with `title`, `description` and `message` fields.

## Generated HTML

Sumi marks generated content HTML as safe, so `{post.html}`, `{post.excerpt}`, `{page.html}` and `{content}` render as HTML without `| raw`. Ordinary strings still escape by default.

Use `| raw` only when you intentionally need to render your own trusted string as HTML.

## Theme commands

Check a theme without building the site:

```bash
./sumi theme check
```

Format templates:

```bash
./sumi theme format
./sumi theme format --check
```

Run the language server, the tool that gives your editor checking and completions as you type:

```bash
./sumi theme language-server
```

For VS Code and Nova, install the Sumi extension from the [latest release](https://github.com/NekoLabStudio/sumi/releases/latest): the `.vsix` file for VS Code, or the zipped `.novaextension` for Nova. It highlights `.sumi` files, runs the language server through your site's `./sumi` and adds commands for checking templates, the dev server and building.

## Assets and images

Use `asset()` for theme files that should be copied to the built site with a fingerprinted URL, a filename that changes whenever the file changes, so browsers never serve a stale copy:

```sumi
<img src="{asset('images/avatar.png')}" alt="Ivo">
```

Relative asset paths are resolved relative to the template or component file first, then relative to the theme folder. Theme assets are emitted under `/assets/sumi/`.

For images, prefer `@image`. Sumi resolves the asset, fingerprints theme images, adds dimensions when it can read them and defaults to `loading="lazy"` and `decoding="async"`:

```sumi
@image("images/avatar.png", alt: "Ivo", class: "avatar", sizes: "64px")
```

Add `widths:` to generate responsive variants and a `srcset` automatically:

```sumi
@image("images/hero.jpg", alt: "Coastal path", widths: [480, 960, 1440], sizes: "(min-width: 960px) 960px, 100vw")
```

Site media references such as `/media/photo.jpg` keep their public media path. Theme-local images and responsive variants are copied to `/assets/sumi/`.

For static files that should be copied without Sumi processing, use passthrough assets in `sumi.json`. See [Site Configuration](site-configuration.md).

## Styles and scripts

Sumi templates can declare styles and scripts next to the markup that uses them. Sumi extracts those resources into fingerprinted files under `/assets/sumi/` and injects them into the page:

```sumi
@style(file: "styles/site.css")
@script(file: "scripts/site.sumi")
```

You can also write inline resource blocks:

```sumi
@style(scoped) {
  .photo-grid {
    display: grid;
    gap: 1rem;
  }
}

@script {
  let menu = page.query("#menu")

  on ".menu-toggle".click {
    menu.toggleClass("is-open")
  }
}
```

For the full resource model, see [Resources](../templates/resources.md).

## Interactivity

Themes can respond to clicks and other browser events without you writing separate JavaScript. Sumi emits `/assets/sumi-runtime.js` only on pages that use Sumi state, state bindings, style bindings, browser actions or enhanced navigation:

```sumi
@state expanded = false

<button on:click="{expanded.toggle()}" aria-expanded="{expanded}">
  {expanded ? "Hide" : "Show"} details
</button>

<section hidden?="{!expanded}" class:open="{expanded}">
  {post.excerpt}
</section>
```

Use `@navigation` in `theme/layouts/default.sumi` when same-origin links should fetch and swap page content without a full reload:

```sumi
@navigation(root: "main", viewTransitions: true, scroll: "top") {
  on:beforeSwap {
    page.addClass("is-leaving")
  }

  on:afterSwap {
    page.removeClass("is-leaving")
  }
}
```

See [Behaviour](../templates/behaviour.md) for state, actions, measurement, viewport events, scripts and navigation hooks.

## Template context

Templates receive:

- `site`
- `posts`
- `pages`
- `categories`
- `photoPosts`
- `data`, containing configured build-time JSON data sources
- `collections.posts`
- `collections.pages`
- `collections.categories`
- `collections.photoPosts`
- `collections.<name>`, for custom Markdown collections
- `pagination` on index and category pages
- `post` on post pages
- `page` on page pages
- `category` on category pages
- `notFound` on the 404 page
- `meta`
- `now`, including `now.year`

`meta` includes `title`, `canonicalUrl` and `description`. Post and page pages use an excerpt of their own content for `meta.description`; index and category pages use `site.description`.

Post objects include `previous` and `next` so themes can add post navigation.

`photoPosts` is intended for photography grids. It includes photo notes whose primary image is not a PNG, so screenshots and other PNG notes do not appear there by default.

Custom collections are exposed by folder name. For example, Markdown files in `content/collections/books` are available as `collections.books`:

```sumi
@for book in collections.books {
  <article>
    <h2>{book.title}</h2>
    <p>{book.author}</p>
    {book.content}
  </article>
}
```

Configured data sources are exposed under `data`:

```sumi
@for event in data.events {
  <article>
    <h2>{event.title}</h2>
    <time datetime="{event.date}">{event.date}</time>
  </article>
}
```

See [Site Configuration](site-configuration.md) for configuring collections and data sources.

## Layouts

If a template returns a full HTML document, Sumi uses it as-is. Otherwise, the rendered content is wrapped in a layout.

Override `theme/layouts/default.sumi` to control the document shell.

## Feed templates

Sumi writes RSS at `/feed.xml` and JSON Feed at `/feed.json`.

Override these files to customise them:

```txt
theme/pages/feed.xml.sumi
theme/pages/feed.json.sumi
```

Both templates receive a `feed` object with:

- `title`
- `description`
- `url`
- `path`
- `items`
- `category`

Category feeds use the same templates with `feed.category` populated and `feed.items` scoped to that category.

RSS browser presentation is optional. In `theme/pages/feed.xml.sumi`, declare `@style` and `@script` resources, then include `feed.presentationScriptSrc` where you want the browser presentation script to appear. RSS readers still receive RSS.

## Build hooks

Use hooks when a theme needs generated assets before Sumi copies passthrough files or resolves Sumi asset references. A common use is bundling larger JavaScript modules or compiling CSS before referencing the output with `@script(file:)` or `@style(file:)`:

```json
{
  "hooks": {
    "beforeBuild": ["./build-theme-assets.sh"]
  }
}
```

This keeps bundling outside the engine while still making `./sumi build` produce a complete site.
