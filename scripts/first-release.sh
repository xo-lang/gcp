#!/bin/sh
# The first release (docs/release-checklist.md): tags the root module and
# every API module under it at HEAD with one version (v0.1.0 for the
# first). Every API module requires the root at that version and the same
# commit; none requires another, so there is no cycle. codegen is not
# published. Without --push it checks the tree and the requires and
# prints the tags in order (the root first).
# With --push it creates annotated tags at HEAD and pushes them to
# $TAG_REMOTE (origin by default); scripts/check-release.sh does that
# against a scratch bare clone first.
# Usage: scripts/first-release.sh v0.1.0 [--push]
set -eu
cd "$(dirname "$0")/.."
v=${1-}
push=0
[ "${2-}" = --push ] && push=1
remote=${TAG_REMOTE:-origin}
echo "$v" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || { echo "first-release: want a version like v0.1.0" >&2; exit 2; }
if [ -n "$(git status --porcelain)" ]; then
  echo "first-release: the working tree is not clean" >&2
  exit 1
fi
if [ -n "$(git tag -l 'v*' '*/v*')" ]; then
  echo "first-release: tags exist already" >&2
  exit 1
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git ls-files '*xo.mod' | sed 's#/*xo.mod$##' | grep -vx codegen | grep -v '^$' > "$tmp/mods"
: > "$tmp/err"
while read -r m; do
  grep -qx "require github.com/xo-lang/gcp $v" "$m/xo.mod" || echo "$m/xo.mod does not require the root $v" >> "$tmp/err"
  grep -x 'require github.com/xo-lang/gcp/.*' "$m/xo.mod" | while read -r _ p ver; do
    d=${p#github.com/xo-lang/gcp/}
    [ "$ver" = "$v" ] || echo "$m/xo.mod requires $p $ver, not $v" >> "$tmp/err"
    grep -qx "$d" "$tmp/mods" || echo "$m/xo.mod requires $p, which is not a published module" >> "$tmp/err"
  done
done < "$tmp/mods"
if [ -s "$tmp/err" ]; then
  sed 's/^/first-release: /' "$tmp/err" >&2
  exit 1
fi
grep -hx 'require github.com/xo-lang/gcp/.*' $(sed 's#$#/xo.mod#' "$tmp/mods") | awk '{print $2}' | sed 's#^github.com/xo-lang/gcp/##' | sort -u > "$tmp/deps"
{ echo "$v"; sed "s#\$#/$v#" "$tmp/deps"; grep -vxF -f "$tmp/deps" "$tmp/mods" | sed "s#\$#/$v#"; } > "$tmp/tags"
n=$(wc -l < "$tmp/tags" | tr -d ' ')
echo "first-release: $n tags at $(git rev-parse --short HEAD), in order:"
head -5 "$tmp/tags" | sed 's/^/  /'
echo "  ... ($((n - 5)) more)"
if [ $push -eq 0 ]; then
  echo "first-release: dry run; --push creates and pushes them to $remote"
  exit 0
fi
while read -r t; do
  git tag -a "$t" -m "$t"
done < "$tmp/tags"
split -l 50 "$tmp/tags" "$tmp/part."
for p in "$tmp"/part.*; do
  # shellcheck disable=SC2046
  git push -q "$remote" $(sed 's#^#refs/tags/#' "$p")
done
echo "first-release: pushed $n tags to $remote"
