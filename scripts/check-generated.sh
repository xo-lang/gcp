#!/bin/sh
# Regenerates every module in codegen/services.toml and fails if the
# result differs from what git holds (decision 0002: generated code is
# committed and regenerating must leave it unchanged). The Discovery
# documents come from google.golang.org/api at the rows' go_version in
# the Go module cache (`go mod download google.golang.org/api@<version>`
# fetches it from the Go module proxy).
# Usage: XO_CLI=/path/to/xo scripts/check-generated.sh
set -u
cd "$(dirname "$0")/.."
xo=${XO_CLI:-xo}
ver=$(awk -F'"' '/^go_version *=/ { print $2 }' codegen/services.toml)
api=${GOMODCACHE:-$HOME/go/pkg/mod}/google.golang.org/api@$ver
if [ ! -d "$api" ]; then
  echo "check-generated: google.golang.org/api@$ver is not in the module cache: go mod download google.golang.org/api@$ver" >&2
  exit 2
fi
dirs=$(awk -F'"' '/^dir *=/ { print $2 }' codegen/services.toml)
if [ -n "$(git status --porcelain -- $dirs)" ]; then
  echo "check-generated: generated modules have uncommitted changes: commit or stash them first" >&2
  exit 1
fi
if ! "$xo" run ./codegen/cmd/gen -- "$api" all >/dev/null; then
  echo "check-generated: the generator failed" >&2
  exit 1
fi
if [ -n "$(git status --porcelain -- $dirs)" ]; then
  echo "check-generated: modules differ from their regeneration:" >&2
  git status --short -- $dirs | head -40 >&2
  echo "check-generated: FAILED"
  exit 1
fi
echo "check-generated: ok ($(echo "$dirs" | grep -c .) modules)"
