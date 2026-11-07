#!/bin/sh
# The Go vectors of modules (decision 0005): for each, writes the Go
# program (codegen/cmd/govec), builds it with Go's module (the module
# proxy only fills the module cache; the build is offline), runs it
# under env -i (a fake transport: no network), writes
# govectors_test.xo from its output, and runs the module's tests. Prints
# one line a module: Go-verified, compiled (with the failing count), or
# the step that failed.
# Usage: XO_CLI=/path/to/xo WORK=<scratch dir> scripts/verify.sh <module dir>...
set -u
cd "$(dirname "$0")/.."
xo=${XO_CLI:-xo}
work=${WORK:?WORK: a scratch directory}
go=${GO:-go}
gobin=$(dirname "$(command -v "$go")")
mkdir -p "$work/gohome"
ver=$(awk -F'"' '/^go_version *=/ { print $2 }' codegen/services.toml)
api=${GOMODCACHE:-$HOME/go/pkg/mod}/google.golang.org/api@$ver
genv="env -i HOME=$work/gohome PATH=/usr/bin:/bin:$gobin TMPDIR=$work/gohome GOMODCACHE=${GOMODCACHE:-$HOME/go/pkg/mod} GOCACHE=$work/gohome/gocache GOFLAGS=-mod=mod"
"$xo" build -o "$work/govec" ./codegen/cmd/govec > /dev/null || { echo "verify: govec did not build"; exit 2; }
for d in "$@"; do
  n=$(echo "$d" | tr / _)
  p="$work/$n.prog"
  rm -rf "$p"
  if ! "$work/govec" go "$api" "$d" "$p" > "$work/$n.govec" 2>&1; then echo "$d govec-failed"; continue; fi
  # the dependencies' sums: the first module's tidy fills the cache
  if [ -f "$work/go.sum" ]; then cp "$work/go.sum" "$p/go.sum"; fi
  (cd "$p" && $genv $go mod tidy > "$work/$n.tidy" 2>&1) || { echo "$d go-tidy-failed"; continue; }
  [ -f "$work/go.sum" ] || cp "$p/go.sum" "$work/go.sum"
  if ! (cd "$p" && $genv GOPROXY=off $go build -o prog . > "$work/$n.build" 2>&1); then
    echo "$d go-program-failed: $(grep -m1 -E '\.go:[0-9]+' "$work/$n.build" | sed 's/.*main\.go:[0-9]*:[0-9]*: //')"
    continue
  fi
  env -i HOME="$work/gohome" PATH=/usr/bin:/bin TMPDIR="$work/gohome" "$p/prog" > "$work/$n.go.out" 2> "$work/$n.go.err" || true
  if grep -q '^panic: ' "$work/$n.go.err"; then
    echo "$d go-program-panicked: $(grep -m1 '^panic: ' "$work/$n.go.err" | cut -c8-)"
    continue
  fi
  if ! "$work/govec" xo "$api" "$d" "$work/$n.go.out" > "$work/$n.vectors" 2>&1; then echo "$d vectors-failed"; continue; fi
  if grep -q ': 0 vector tests$' "$work/$n.vectors"; then
    rm -f "$d/govectors_test.xo" "$d/govec_fake_test.xo"
    echo "$d Go-verified (no methods)"
    rm -rf "$p"
    continue
  fi
  cp codegen/govec/fake_test.xo.txt "$d/govec_fake_test.xo"
  (cd "$d" && "$xo" test . > "$work/$n.test" 2>&1)
  r=$(grep -E '^(ok|FAIL): ' "$work/$n.test" | tail -1)
  case $r in
    ok:*) echo "$d Go-verified" ;;
    *)
      # vectors that do not all pass stay out of the tree (kept in $work)
      mv "$d/govectors_test.xo" "$work/$n.new_vectors"
      rm -f "$d/govec_fake_test.xo"
      case $r in
        FAIL:*) echo "$d compiled $(echo "$r" | sed 's/.* \([0-9]*\) failed.*/\1/') failing" ;;
        *) echo "$d test-did-not-run: $(grep -m1 'error' "$work/$n.test")" ;;
      esac ;;
  esac
  rm -rf "$p"
done
