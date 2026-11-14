#!/bin/sh
# Rehearses a first release with no network write (docs/release-checklist.md):
# clones HEAD into a scratch directory with a bare "remote", runs
# scripts/first-release.sh --push against that remote, then type checks
# every published module from the tagged clone with no workspace (after
# `xo mod tidy`, which must leave each xo.mod as it is), fetching
# the modules it requires from the scratch remote (XO_GIT_REWRITE), and
# last an app that gets the root and storage/v1 with
# `xo get` and type checks with no workspace.
# Usage: XO_CLI=/path/to/xo scripts/check-release.sh v0.1.0 [scratch dir]
set -eu
cd "$(dirname "$0")/.."
v=${1:?usage: check-release.sh v0.1.0 [scratch dir]}
xo=${XO_CLI:-xo}
work=${2:-$(mktemp -d)}
mkdir -p "$work"
src=$(pwd)
# the module cache is read-only, as Go's is
[ -d "$work/modcache" ] && chmod -R u+w "$work/modcache"
rm -rf "$work/remote.git" "$work/clone" "$work/app" "$work/modcache"
git clone -q --bare "$src" "$work/remote.git"
git clone -q "$work/remote.git" "$work/clone"
(cd "$work/clone" && GIT_COMMITTER_NAME=release-check GIT_COMMITTER_EMAIL=release-check@invalid TAG_REMOTE=origin sh scripts/first-release.sh "$v" --push)
export XO_GIT_REWRITE="github.com/xo-lang/gcp=$work/remote.git"
export XO_MODCACHE="$work/modcache"
rm -f "$work/clone/xo.work"
fails=0
n=0
for m in . $(cd "$work/clone" && git ls-files '*/xo.mod' | sed 's#/xo.mod$##' | grep -vx codegen); do
  d="$work/clone/$m"
  n=$((n + 1))
  # the root has no .xo file at the top: its packages are the directories
  # with .xo files outside every nested module (./... would load them all)
  pkgs=.
  [ "$m" = . ] && pkgs=$(cd "$d" && git ls-files '*.xo' | sed 's#/[^/]*$##' | sort -u | awk -v mods="$(git ls-files '*/xo.mod' | sed 's#/xo.mod$##' | tr '\n' ' ')" 'BEGIN { n = split(mods, a, " ") } { for (i = 1; i <= n; i++) if ($0 == a[i] || index($0, a[i] "/") == 1) next; print "./" $0 }')
  # tidy records the lock (no module carries one) and must not change the
  # requires: a change means a missing or extra require.
  if ! (cd "$d" && "$xo" mod tidy > "$work/check.out" 2>&1 && git diff --quiet -- xo.mod && "$xo" check --workspace=off $pkgs >> "$work/check.out" 2>&1); then
    echo "check-release: FAIL $m"
    (cd "$d" && git diff --stat -- xo.mod) | sed 's/^/  /'
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
use github.com/xo-lang/gcp/storage/apiv1 as storage

fn main(os: Os) {
  os.stdio.println("${gensupport.VERSION} ${storage.API_ID}")
}
XO
"$xo" get github.com/xo-lang/gcp@"$v" github.com/xo-lang/gcp/storage/apiv1@"$v" > "$work/get.out" 2>&1 || { echo "check-release: FAIL xo get"; tail -5 "$work/get.out"; exit 1; }
"$xo" check --workspace=off . > "$work/app.out" 2>&1 || { echo "check-release: FAIL app"; tail -5 "$work/app.out"; exit 1; }
echo "check-release: an app got the root and storage/v1 at $v and checks"
# decision 0014: the root and the API modules reach only what a request
# needs; credential discovery is its own module, and the wider set shows
# there alone
"$xo" get github.com/xo-lang/gcp/auth/credentials@"$v" > "$work/get2.out" 2>&1 || { echo "check-release: FAIL xo get auth/credentials"; tail -5 "$work/get2.out"; exit 1; }
for m in github.com/xo-lang/gcp github.com/xo-lang/gcp/storage/apiv1 github.com/xo-lang/gcp/compute/metadata; do
  fx=$(awk -v m="$m" '$1 == m && $2 == "effects" { print $3 }' xo.lock)
  want=clock,net.dial,rand
  [ "$m" = github.com/xo-lang/gcp/compute/metadata ] && want=clock,env,net.dial,rand
  [ "$fx" = "$want" ] || { echo "check-release: FAIL $m effects '$fx', want $want (decision 0014)"; exit 1; }
done
echo "check-release: effects: $(awk '$2 == "effects" { printf "%s %s; ", $1, $3 }' xo.lock)"
[ $fails -eq 0 ]
