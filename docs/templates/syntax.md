# Syntax

Sumi syntax is deliberately small. Templates stay close to HTML, and the extra syntax is reserved for values, control flow, reusable components, resources and behaviour. This page covers the core language: output, expressions, conditionals, loops, filters, methods and attribute helpers.

## Output

Use `{expression}` for normal escaped output:

```sumi
<h1>{post.title}</h1>
```

Expressions can start with values, literals, function calls or filters:

```sumi
{"Draft" | downcase}
{"/photos/a b.jpg" | urlEncode}
{asset("images/avatar.png")}
```

### Safe HTML and raw output

Ordinary strings are escaped. HTML that Sumi generates, such as rendered post content, renders as HTML. Use `| raw` only for trusted content:

```sumi
<article>{post.html}</article>
<article>{customHTML | raw}</article>
```

### Quoting attribute values

> **Warning:** Always quote an interpolated attribute value. Escaping covers text and quoted attributes, so `<a href="{url}">` is safe. An *unquoted* value like `<a href={url}>` is not: a value with a space could add an attribute of its own. Quote every attribute that contains `{...}`.

## Expressions

Expressions can read values from the context, local variables, loop variables, component arguments and functions such as `asset()`:

```sumi
{site.title}
{post.author.name}
{posts.size}
{asset("images/avatar.png")}
```

### Literals

Supported literals include strings, numbers, booleans, `nil`, `null`, `empty`, `blank` and arrays:

```sumi
@let widths = [480, 960, 1440]
@let fallbackTitle = "Untitled"
```

### Operators

Comparisons and boolean operators work in conditionals and bindings:

```sumi
@if post.title && post.urlPath.startsWith("/notes/") {
  <a href="{post.urlPath}">{post.title}</a>
}

<button disabled?="{items.size == 0}">Continue</button>
```

Operators follow Swift's precedence: prefix `!` binds tightest, then `??`, then comparisons, then `&&`, then `||`. So `!a == b` evaluates as `(!a) == b`.

> **Note:** This precedence changed in Sumi 2.0. Earlier versions parsed `!a == b` as `!(a == b)`.

### Ternaries

Use ternaries for small inline choices:

```sumi
<span>{post.title ? post.title : "Untitled"}</span>
```

### Truthiness

For conditionals, empty strings, empty arrays, `false`, `nil` and `null` are falsey. Non-empty strings, non-empty arrays, numbers, dictionaries and safe HTML are truthy.

## Locals

Use `@let` for local values:

```sumi
@let currentPath = meta.canonicalUrl.replace(site.url, "")
@let isActive = currentPath == "/photos/"

<a href="/photos/" class:active="{isActive}">Photos</a>
```

## Conditionals

Use `@if`, `else if` and `else`:

```sumi
@if post.title {
  <h1>{post.title}</h1>
} else if site.title {
  <h1>{site.title}</h1>
} else {
  <h1>Untitled</h1>
}
```

### Optional binding

Bind an optional with Swift-style `@if let`; the name is in scope for the body:

```sumi
@if let author = post.author {
  <p>By {author.name}</p>
} else {
  <p>Anonymous</p>
}
```

### Nil coalescing

Coalesce a missing value with `??`. Only nil/null falls back; an empty string is a value, as in Swift. It binds tighter than comparison and is right-associative:

```sumi
<title>{post.title ?? site.title ?? "Untitled"}</title>
```

## Loops

Use `@for` to render arrays:

```sumi
@for post in posts {
  <article>
    <h2>{post.title}</h2>
  </article>
}
```

Loop metadata is available through `forloop`:

```sumi
@for item in items {
  <span>{forloop.index}</span>
}
```

The available loop values are:

| Value | Meaning |
| --- | --- |
| `forloop.index` | Position, starting at 1 |
| `forloop.index0` | Position, starting at 0 |
| `forloop.rindex` | Counts down to 1 |
| `forloop.rindex0` | Counts down to 0 |
| `forloop.first` | True on the first iteration |
| `forloop.last` | True on the last iteration |
| `forloop.length` | The total number of iterations |

## Comments

Use `@comment` when you want Sumi to ignore a block entirely:

```sumi
@comment {
  <p>This does not render.</p>
  @PostCard(post)
}
```

## Filters

Filters transform values:

```sumi
{post.title | default("Untitled")}
{post.dateIso | date("d MMMM yyyy")}
{tags | join(", ")}
{content | raw}
```

The most common filters:

- `default(value)`: substitute for missing or empty values. The number `0` is kept.
- `date(format)`: format a date.
- `join(separator)`, `sort(field)`, `where(field, value)`, `map(field)`: work with arrays.
- `upcase`, `downcase`, `truncate(length)`, `slugify`: transform strings.

See [Filters](filters.md) for the complete reference, covering every string, array, number, date and output filter.

## Methods

Some values also support method-style calls:

```sumi
@if post.urlPath.startsWith("/photos/") {
  <span>Photo post</span>
}

{post.title.replace(":", " - ")}
```

Useful methods include `contains`, `startsWith`, `endsWith`, `replace`, `replaceFirst`, `split`, `lowercased`, `uppercased` and `slugify`.

## Attributes

Classes and attributes often depend on a condition, and writing that with `@if` gets noisy. Sumi includes helpers for the common cases:

```sumi
<a
  href="{post.urlPath}"
  class="nav-link"
  class:active="{isActive}"
  class+="{post.kind}"
  aria-current:page="{isActive}"
  target?="{target}"
>
  {post.title}
</a>
```

The helpers are:

| Helper | Effect |
| --- | --- |
| `class:name="{condition}"` | Appends the class when the condition is true |
| `class+="{value}"` | Appends dynamic class names |
| `attribute?="{value}"` | Omits the attribute when the value is empty or false |
| `attribute:value="{condition}"` | Writes `attribute="value"` when true |
| `style:name="{value}"` | Binds an inline style property |

Style bindings work with ordinary properties and custom properties:

```sumi
<span style:--offset="{offset}px" style:opacity="{visible ? 1 : 0}"></span>
```
