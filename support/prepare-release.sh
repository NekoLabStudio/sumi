#!/usr/bin/env bash
#
# prepare-release.sh <version>
#
# Performs every FILE edit a release needs, in one deterministic pass:
#   • Sources/Sumi/Config/SumiConfig.swift
#       → currentVersion = "<version>"
#   • editors/vscode/package.json and the Nova extension.json
#       → "version": "<version>"
#   • docs/upgrading/next.md → docs/upgrading/<version>.md
#     (retitled, unreleased-intro block dropped, fresh next.md started,
#      index.md version list updated). A next.md still at its "Nothing yet."
#     placeholder rolls into a short all-clear page — no flag needed for a
#     purely additive release.
#
# Deliberately NO git operations: the prepare-release workflow (the normal way
# to cut a release) commits, tags and pushes around this script, and a human
# running it locally stays in control of their own git.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"

if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "usage: support/prepare-release.sh <MAJOR.MINOR.PATCH>" >&2
  exit 1
fi

CONFIG="Sources/Sumi/Config/SumiConfig.swift"
CURRENT="$(sed -n 's/.*currentVersion = "\(.*\)".*/\1/p' "$CONFIG")"
if [ "$CURRENT" = "$VERSION" ]; then
  echo "currentVersion is already $VERSION — nothing to do?" >&2
  exit 1
fi

# 1. The version (drives `sumi version`, self-update, and the
#    per-site launcher pin; release.yml refuses a tag that doesn't match it).
sed -i.bak "s/currentVersion = \"$CURRENT\"/currentVersion = \"$VERSION\"/" "$CONFIG"
rm "$CONFIG.bak"
grep -q "currentVersion = \"$VERSION\"" "$CONFIG"

# Editor extensions track the Sumi version (release.yml enforces it).
# A plain substitution, guarded to exactly one "version" key per manifest,
# because GNU sed's first-match-only address form doesn't exist on BSD sed.
for manifest in editors/vscode/package.json editors/nova/Sumi.novaextension/extension.json; do
  occurrences="$(grep -c '"version":' "$manifest")"
  if [ "$occurrences" != "1" ]; then
    echo "$manifest has $occurrences \"version\" keys, expected exactly 1" >&2
    exit 1
  fi
  sed -i.bak "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/" "$manifest"
  rm "$manifest.bak"
  grep -q "\"version\": \"$VERSION\"" "$manifest"
done

# 2. Roll the upgrade notes.
NEXT="docs/upgrading/next.md"
PAGE="docs/upgrading/$VERSION.md"
if [ ! -f "$NEXT" ]; then
  echo "$NEXT is missing" >&2
  exit 1
fi
if [ -f "$PAGE" ]; then
  echo "$PAGE already exists" >&2
  exit 1
fi

# The rolled page: retitled, intro block dropped. When next.md is still at its
# placeholder (an additive release), the page becomes an explicit all-clear
# instead — better than an absent page users can't distinguish from a mistake.
BODY="$(sed -e '1d' -e '/<!-- unreleased-intro-start/,/<!-- unreleased-intro-end -->/d' "$NEXT" \
        | grep -v '^$' || true)"
if [ "$BODY" = "Nothing yet." ]; then
  cat > "$PAGE" <<ALLCLEAR
# Sumi $VERSION

Nothing needs changing in your site: update Sumi and rebuild.
ALLCLEAR
else
  sed -e "1s/^# Unreleased$/# Sumi $VERSION/" \
      -e '/<!-- unreleased-intro-start/,/<!-- unreleased-intro-end -->/d' \
      "$NEXT" > "$PAGE"
fi
grep -q "^# Sumi $VERSION$" "$PAGE"

cat > "$NEXT" <<'TEMPLATE'
# Unreleased

<!-- unreleased-intro-start (support/prepare-release.sh drops this block at release) -->
The notes for the next release: everything below is in `main` and ships
together when the version is tagged.
<!-- unreleased-intro-end -->

Nothing yet.
TEMPLATE

# The version list in the section index, newest first (under the marker).
# Site-absolute link, the convention throughout docs/.
sed -i.bak "/<!-- newest-first/a\\
- [Sumi $VERSION](/upgrading/$VERSION/)
" docs/upgrading/index.md
rm docs/upgrading/index.md.bak
grep -q "(/upgrading/$VERSION/)" docs/upgrading/index.md

echo "Prepared release $VERSION (was $CURRENT):"
echo "  $CONFIG"
echo "  editors/vscode/package.json"
echo "  editors/nova/Sumi.novaextension/extension.json"
echo "  docs/upgrading/$VERSION.md (from next.md, fresh next.md started)"
