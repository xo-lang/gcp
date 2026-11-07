# 0007: gRPC clients wait for a std decision

Status: Proposed (for the owner's approval, through the lead).

## Context

`cloud.google.com/go`'s GAPIC clients, and Pub/Sub, Spanner, Bigtable
and Firestore's main paths, speak gRPC (HTTP/2, protobuf, Google's auth
per call, streaming). Xo's std has no gRPC client yet.

## Decision

- No gRPC client is written in this repository. The GAPIC clients are
  out of scope until Xo's std has a gRPC decision (its own ADR in the
  xo repository); then a record here decides how the protobuf service
  definitions are read and the GAPIC surface generated.
- Where Go offers a REST transport for a GAPIC client, it is not ported
  ahead of gRPC either, so the two transports keep one generator.

## Consequences

- The first scope is google.golang.org/api's REST packages
  ([0001](0001-scope-and-layout.md)), which cover most services' REST
  surfaces (including Pub/Sub's, Firestore's and Spanner's v1 REST
  APIs).

## Alternatives

- A gRPC client in this repository: would be a std concern written in
  the wrong place, and would need HTTP/2 and protobuf support that std
  should own.
