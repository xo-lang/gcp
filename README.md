# Google Cloud for Xo

A port of Google's Go SDK for Google Cloud, starting with
google.golang.org/api's REST packages, generated from the Discovery
documents Go itself ships and checked against Go byte for byte.

Status: every API version Go ships (667 modules, google.golang.org/api
v0.311.0) is generated and type-checks; none is Go-verified yet (the
vector programs come next). Media upload and download are not generated
yet: their methods' JSON calls are. The records in
[docs/decisions](docs/decisions/README.md) were accepted by the owner on
2026-11-07. Local only until the owner approves publishing.

## Layout

- `auth`, `gensupport`, `googleapi`, `option`: the hand-written core.
- `<api>/<version>`: one generated module per API version, at Go's
  package path (`storage/v1`).
- `codegen`: the generator (`codegen/cmd/gen`) and the tool that derives
  its rows from Go's module (`codegen/gorows`).
- `scripts/gate.sh`: tests, type-checks, `xo fmt`, and regeneration;
  `scripts/check-public.sh` before any commit.
