# Google Cloud for Xo

A community Google Cloud SDK for the Xo language. Not affiliated with or
endorsed by Google. Google Cloud is a trademark of Google LLC.

A port of Google's Go SDK for Google Cloud, starting with
google.golang.org/api's REST packages, generated from the Discovery
documents Go itself ships and checked against Go byte for byte.

Status (google.golang.org/api v0.311.0, 667 modules; the full table is
[docs/reports/gcp-go-coverage.md](docs/reports/gcp-go-coverage.md)):

- **Go-verified: 667 of 667.** Every method is called in Go and here
  with the same arguments against the same fake service, and the
  requests, the responses served and the decoded results are compared
  (34,228 vector tests, pagers, media upload and download among them),
  natively on darwin/arm64 and linux/arm64.
  discoveryengine/v1 and v1alpha are generated from the older document
  Go's package for them was built from (google.golang.org/api v0.293.0;
  see [not-generated.md](docs/reports/not-generated.md)).
- **Not ported yet: cloud.google.com/go** (206 modules: 724 GAPIC
  clients over gRPC, plus the hand-written storage, bigquery, spanner,
  firestore, pubsub and auth clients), and real credentials (`auth` is a
  static token). See
  [gcp-cloud-go-coverage.md](docs/reports/gcp-cloud-go-coverage.md).

No real Google Cloud endpoint is called anywhere: every test runs
against local fakes. The records in
[docs/decisions](docs/decisions/README.md) were accepted by the owner.

## Install

Every module is tagged v0.1.0 (the first release, with Xo 0.46.0). Get
the API versions your program uses; each requires the root:

    xo get github.com/xo-lang/gcp@v0.1.0
    xo get github.com/xo-lang/gcp/storage/v1@v0.1.0

Requires Xo 0.45.0 or later. Release notes:
[docs/releases/v0.1.0.md](docs/releases/v0.1.0.md).

## Layout

- `auth`, `gensupport`, `googleapi`, `option`: the hand-written core.
- `<api>/<version>`: one generated module per API version, at Go's
  package path (`storage/v1`).
- `codegen`: the generator (`codegen/cmd/gen`) and the tool that derives
  its rows from Go's module (`codegen/gorows`).
- `scripts/gate.sh`: tests, type-checks, `xo fmt`, and regeneration;
  `scripts/check-public.sh` before any commit.
