#!/bin/sh
# The gate: tests every hand-written package (the root module's and the
# generator's), type-checks every generated module, checks xo fmt's
# layout, and that regenerating changes nothing.
# Usage: XO_CLI=/path/to/xo scripts/gate.sh
set -u
cd "$(dirname "$0")/.."
xo=${XO_CLI:-xo}
fail=0
gen=$(awk -F'"' '/^dir *=/ { print "./" $2 }' codegen/services.toml)
for d in auth gensupport googleapi option; do
  echo "== $d"
  "$xo" test "./$d" || fail=1
done
echo "== codegen"
(cd codegen && "$xo" test ./gen) || fail=1
echo "== check (generated modules)"
# shellcheck disable=SC2086
"$xo" check $gen || fail=1
if ! "$xo" fmt --check ./...; then
  echo "gate: xo fmt --check: the files above need xo fmt"
  fail=1
fi
XO_CLI=$xo scripts/check-generated.sh || fail=1
[ $fail -eq 0 ] && echo "gate: ok" || echo "gate: FAILED"
exit $fail
