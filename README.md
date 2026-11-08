# Google Cloud for Xo

A port of Google's Go SDK for Google Cloud, starting with
google.golang.org/api's REST packages, generated from the Discovery
documents Go itself ships and checked against Go byte for byte.

Status (google.golang.org/api v0.311.0, 667 modules; the full table is
[docs/reports/gcp-go-coverage.md](docs/reports/gcp-go-coverage.md)):

- **Go-verified: 665.** Every method is called in Go and here with the
  same arguments against the same fake service, and the requests, the
  responses served and the decoded results are compared (32,390 vector
  tests, pagers, media upload and download among them).
  discoveryengine/v1 and v1alpha are generated from the older document
  Go's package for them was built from (google.golang.org/api v0.293.0;
  see [not-generated.md](docs/reports/not-generated.md)).
- **Go-verified on some targets only: 2** (aiplatform/v1 and
  compute/v0.alpha): they pass on linux/arm64 native and on Go's
  backend; on darwin/arm64 the default separate link of their large
  test binaries hits an Xo bug, being fixed in Xo.

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
