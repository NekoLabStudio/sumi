# Unreleased

<!-- unreleased-intro-start (support/prepare-release.sh drops this block at release) -->
The notes for the next release: everything below is in `main` and ships
together when the version is tagged.
<!-- unreleased-intro-end -->

## Redesigned default theme

Sumi's built-in default theme has been redesigned with a warm paper and charcoal palette, a top accent bar, tinted header and footer bands, a continuous reading stream for articles, notes and photos, topic links on the home page, responsive photo grids and updated prose styling for blockquotes, code blocks and tables.

A template bug where category tags rendered literally as `#{category.name}` on posts has also been fixed.

Sites using the built-in theme pick up the new design automatically on their next build. Sites with an ejected `theme/` folder keep their existing templates untouched.
