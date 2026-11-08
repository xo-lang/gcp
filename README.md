# Google Cloud for Xo

A port of Google's Go SDK for Google Cloud, starting with
google.golang.org/api's REST packages, generated from the Discovery
documents Go itself ships and checked against Go byte for byte.

Status (google.golang.org/api v0.311.0, 667 modules; the full table is
[docs/reports/gcp-go-coverage.md](docs/reports/gcp-go-coverage.md)):

- **Go-verified: 663.** Every method is called in Go and here with the
  same arguments against the same fake service, and the requests, the
  responses served and the decoded results are compared (31,656 vector
  tests, pagers, media upload and download among them).
- **Go-verified on Go's backend only: 2** (aiplatform/v1 and
  compute/v0.alpha): their test binaries hit an Xo bug on native arm64,
  being fixed in Xo.
- **Compiled: 2** (discoveryengine/v1 and v1alpha): Go's package for
  them was generated from an older document than the one it ships;
  they are being moved to that document.

No real Google Cloud endpoint is called anywhere: every test runs
against local fakes. The records in
[docs/decisions](docs/decisions/README.md) were accepted by the owner.

## Layout

- `auth`, `gensupport`, `googleapi`, `option`: the hand-written core.
- `<api>/<version>`: one generated module per API version, at Go's
  package path (`storage/v1`).
- `codegen`: the generator (`codegen/cmd/gen`) and the tool that derives
  its rows from Go's module (`codegen/gorows`).
- `scripts/gate.sh`: tests, type-checks, `xo fmt`, and regeneration;
  `scripts/check-public.sh` before any commit.
