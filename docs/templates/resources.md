# Resources

Sumi templates can declare the CSS, JavaScript and images they need right next to the markup that uses them. Sumi collects those declarations while rendering and turns them into real files instead of forcing everything inline.

The important idea is locality: write the resource next to the markup that needs it, and let Sumi fingerprint, inject, optimise or copy it.

## How collection works

When a template renders, Sumi records resource declarations in the render result. While building the site, it then does the following:

- Fingerprints CSS.
- Emits JavaScript as modules.
- Scopes component styles.
- Resolves static assets.
- Generates responsive images.
- Injects links and scripts into the final document.

Fingerprinted resources are written under `/assets/sumi/`.

## Styles

Use `@style` for CSS that belongs to the current template:

```sumi
@style {
  .post-list {
    display: grid;
    gap: 1rem;
  }
}

<section class="post-list">
  @for post in posts {
    <article>{post.title}</article>
  }
</section>
```

### Scoped styles

A component's CSS often should not leak into the rest of the page. Use scoped styles for that:

```sumi
@component Button(label, variant = "plain") {
  @style(scoped) {
    .button {
      border-radius: 0.4rem;
    }

    .button.primary {
      background: black;
      color: white;
    }
  }

  <button class="button" class+="{variant}">{label}</button>
}
```

Scoped styles are normal CSS. Sumi rewrites the selectors and marks the rendered fragment with a generated scope attribute.

### Style files

CSS files are supported too:

```sumi
@style(file: "styles/site.css")
@style(file: "components/card.css", scoped: true)
```

Use inline styles when the CSS only makes sense next to the template. Use CSS files when the stylesheet is shared, large or edited independently.

## Scripts

`@script` uses Sumi's client script language by default:

```sumi
@script {
  let menu = page.query("#menu")

  on ".menu-toggle".click {
    menu.toggleClass("is-open")
  }
}
```

See [Client scripts](client-scripts.md) for the language reference.

### Script files

Use `.sumi` files when a script should live outside the template:

```sumi
@script(file: "scripts/menu.sumi")
```

### Raw JavaScript

Raw JavaScript is available as an explicit escape hatch:

```sumi
@script(language: "javascript") {
  document.documentElement.dataset.enhanced = "true";
}
```

JavaScript files are treated as raw JavaScript automatically:

```sumi
@script(file: "scripts/site.js")
```

## Scoped scripts

Scoped scripts belong to a rendered fragment. Inside the script, `root` is the fragment's top-level element:

```sumi
@component Disclosure(title) {
  @script(scoped) {
    let button = root.query("button")

    on button.click {
      root.toggleClass("is-open")
    }
  }

  <section>
    <button>{title}</button>
    @slot
  </section>
}
```

Scoped Sumi scripts run once for each rendered fragment. Raw JavaScript modules are copied as modules and do not get `root`.

## Assets

Use the `asset()` function to resolve theme files:

```sumi
<img src="{asset('images/avatar.png')}" alt="Avatar">
```

Sumi checks that the referenced file exists and gives it a fingerprinted public URL. Relative paths resolve against the template or component file first, then the theme folder.

Use `asset()` for files you want to reference from attributes, such as favicons, downloads, fonts and images that do not need generated markup.

## Images

Use `@image` to let Sumi build the `<img>` element:

```sumi
@image(
  "hero.jpg",
  alt: "Coastal path",
  widths: [480, 960, 1440],
  sizes: "(min-width: 960px) 960px, 100vw"
)
```

Sumi resolves the file, adds its dimensions when it can read them, generates the responsive variants and emits the final `<img>` markup.

Common arguments: `src`, `alt`, `class`, `width`, `height`, `loading`, `decoding`, `fetchpriority`, `widths` and `sizes`.

Use `@image` when you want Sumi to produce the `<img>` element or add image metadata. Use `asset()` when you only need a URL.
