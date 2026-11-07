# 0001: Scope, parity target and module layout

Status: Accepted (by the owner, through the lead, 2026-11-07).

## Context

Google's Go SDKs come in two families:

- `google.golang.org/api` (BSD-3-Clause): about 380 REST API packages
  (`storage/v1`, `compute/v1`, ...), each generated from the API's
  Discovery document, which the package carries beside its code
  (`storage/v1/storage-api.json`; 658 such files in v0.293.0). One Go
  module versions all of them together, and its hand-written core is
  `internal/gensupport` (parameters, retries, media upload, resumable
  upload, errors), `googleapi` and `option`.
- `cloud.google.com/go` (Apache-2.0): the GAPIC clients, generated from
  protobuf service definitions and used over gRPC (some also over
  REST), plus hand-written libraries over them (Storage, Pub/Sub,
  BigQuery, Firestore, Spanner).

Both authenticate through `cloud.google.com/go/auth` (Apache-2.0), which
`google.golang.org/api` requires.

The Azure port's lessons apply directly: derive everything from what Go
pins, generate everything Go generates, hand-write only what Go
hand-writes, and verify against Go itself, byte for byte.

## Decision

- The first parity target is `google.golang.org/api`, every API it
  ships, at its newest release: REST over HTTP/JSON, which Xo's std
  covers today.
- `cloud.google.com/go`'s GAPIC clients wait for a std gRPC decision
  ([0007](0007-grpc-deferred.md)); its hand-written libraries that are
  REST underneath (Storage's JSON API, BigQuery's REST client) are later
  candidates, each by its own record.
- Layout, mirroring Go's paths:
  - a root module `github.com/xo-lang/gcp` holding the hand-written core:
    `auth` (cloud.google.com/go/auth's credentials and token sources),
    `gensupport`, `googleapi` and `option` (google.golang.org/api's);
  - one module per API version at Go's package path
    (`storage/v1`, `compute/v1`, `drive/v3`), generated, each requiring
    the root.
- Module paths without `/vN` major suffixes, as in the AWS and Azure
  ports; Go's version (`v0.293.0`) is recorded per module in the
  generator's data, not in the path.
- The repository is local only until the owner decides otherwise
  (`~/godev/claude-space/xolang/gcp`), and when published follows the
  same hygiene as the Azure repository ([0008](0008-license-and-hygiene.md)).

## Consequences

- One Go release refreshes every API at once (one module version), so a
  refresh is one job and one gate, batched by size.
- The port's first useful slice is small: the core plus one API
  (Storage JSON v1) verified against Go, then the bulk.

## Alternatives

- One module for every API, as Go does: a single huge module would make
  every build and gate pay for 380 packages; per-API modules keep the
  gate's memory bounded (the Azure port's Go-backend numbers).
- Start from cloud.google.com/go: most of its surface is gRPC, which Xo
  has no std support for yet.
