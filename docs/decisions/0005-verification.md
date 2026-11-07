# 0005: Verification against Go, through fakes and emulators, never real Google Cloud

Status: Proposed (for the owner's approval, through the lead).

## Context

The Azure port's method works: a Go program, written from Go's own
module source, calls every public method of every client by reflection,
every argument and option filled, against a fake transport; its output
becomes the module's vector tests; the Xo client makes the same calls
against a fake answering the same way and must produce the same lines.
Vectors that do not all pass are not committed, and a module counts as
ported only when its vectors pass.

## Decision

- No real Google Cloud: no call to any `*.googleapis.com` endpoint or
  the metadata server of a real machine, no credentials from this
  machine (`~/.config/gcloud`, `GOOGLE_APPLICATION_CREDENTIALS`, any
  key), and Go programs run under `env -i`. Real-cloud testing needs an
  owner-confirmed plan through the lead, as for AWS and Azure.
- Generated modules: a vector program per module (the Azure govec's
  design: Go's `NewService` with `option.WithHTTPClient` on a fake
  transport and `option.WithoutAuthentication` or a fixed token source,
  each Call built and run by reflection), and `govectors_test.xo` from
  its output. A line is a request (method, URL, headers sorted, body),
  the response served and the result as Go's `json.Marshal` gives it.
- The core: vectors from Go for every piece that has bytes on the wire:
  the service account JWT (fixed key, fixed clock, so the RS256
  signature is deterministic and compared byte for byte), the token
  exchange bodies, the authorized-user refresh, the metadata server
  requests, retry sequences, multipart and resumable uploads.
- Emulators, on loopback only, for end-to-end runs where a REST
  emulator exists: fake-gcs-server for Storage, and the Datastore and
  Pub/Sub emulators where they serve REST (to be confirmed per
  emulator in a slice; gRPC-only ones wait for [0007](0007-grpc-deferred.md)).
- Go-verified, compiled, not generated: the coverage report's statuses,
  written by a tool, never by hand.

## Consequences

- Every Discovery feature (media, nested resources, repeated query
  parameters, `int64` as strings in JSON, `fields`) is checked against
  Go in every API that uses it, as the batches run.

## Alternatives

- Recorded responses from real services: needs real calls and
  credentials, and checks only what was recorded.
