#!/bin/sh
# Rehearses a first release with no network write (docs/release-checklist.md):
# clones HEAD into a scratch directory with a bare "remote", runs
# scripts/first-release.sh --push against that remote, then type checks
# every published module from the tagged clone with no workspace, fetching
# the modules it requires from the scratch remote (XO_GIT_REWRITE), and
# last an app that gets the root, and storage/v1 with
# `xo get` and type checks with no workspace.
# Usage: XO_CLI=/path/to/xo scripts/check-release.sh v0.1.0 [scratch dir]
set -eu
cd "$(dirname "$0")/.."
v=${1:?usage: check-release.sh v0.1.0 [scratch dir]}
xo=${XO_CLI:-xo}
work=${2:-$(mktemp -d)}
mkdir -p "$work"
src=$(pwd)
rm -rf "$work/remote.git" "$work/clone" "$work/app" "$work/modcache"
git clone -q --bare "$src" "$work/remote.git"
git clone -q "$work/remote.git" "$work/clone"
(cd "$work/clone" && GIT_COMMITTER_NAME=release-check GIT_COMMITTER_EMAIL=release-check@invalid TAG_REMOTE=origin sh scripts/first-release.sh "$v" --push)
export XO_GIT_REWRITE="github.com/xo-lang/gcp=$work/remote.git"
export XO_MODCACHE="$work/modcache"
rm -f "$work/clone/xo.work"
fails=0
n=0
for m in $(cd "$work/clone" && git ls-files '*xo.mod' | sed 's#/*xo.mod$##' | grep -vx codegen); do
  d="$work/clone/${m:-.}"
  n=$((n + 1))
  if ! (cd "$d" && "$xo" check --workspace=off . > "$work/check.out" 2>&1); then
    echo "check-release: FAIL ${m:-root}"
    tail -5 "$work/check.out" | sed 's/^/  /'
    fails=$((fails + 1))
  fi
done
echo "check-release: $n modules checked with no workspace, $fails failed"
mkdir -p "$work/app"
cd "$work/app"
printf 'module example.com/app\nedition preview\n' > xo.mod
cat > main.xo <<'XO'
use github.com/xo-lang/gcp/gensupport
use github.com/xo-lang/gcp/storage/v1 as storage

fn main(os: Os) {
  os.stdio.println("${gensupport.VERSION} ${storage.API_ID}")
}
XO
"$xo" get github.com/xo-lang/gcp@"$v" github.com/xo-lang/gcp/storage/v1@"$v" > "$work/get.out" 2>&1 || { echo "check-release: FAIL xo get"; tail -5 "$work/get.out"; exit 1; }
"$xo" check --workspace=off . > "$work/app.out" 2>&1 || { echo "check-release: FAIL app"; tail -5 "$work/app.out"; exit 1; }
echo "check-release: an app got the root, and storage/v1 at $v and checks"
[ $fails -eq 0 ]
