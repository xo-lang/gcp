# Decisions

Architecture decision records, numbered `NNNN-short-title.md`, each with
Status, Context, Decision, Consequences, Alternatives. A reversed decision
gets a new record and the old one is marked `Superseded by NNNN`; none is
deleted.

- [0001](0001-scope-and-layout.md): google.golang.org/api's REST packages first, every API at Go's newest release; a core root module and one module per API version at Go's paths (Accepted, 2026-11-07)
- [0002](0002-discovery-and-generator.md): the Discovery JSON Go commits in each package, read from the Go module cache; a generator in Xo with committed output; per-API data derived from Go (Accepted, 2026-11-07)
- [0003](0003-hand-written-core.md): hand-written only where Go hand-writes: cloud.google.com/go/auth's credentials and google.golang.org/api's gensupport, googleapi and option (Accepted, 2026-11-07)
- [0004](0004-api-shape.md): Go's service, resource and method tree in Xo style: required parameters, then an options struct; pagers; Go's requests byte for byte (Accepted, 2026-11-07)
- [0005](0005-verification.md): Go vector programs over a fake transport for every module and the core, REST emulators on loopback, never real Google Cloud (Accepted, 2026-11-07)
- [0006](0006-bulk-rules.md): every API generated from the first commit, customization only as data derived from Go, batched differentials and a written coverage report (Accepted, 2026-11-07)
- [0007](0007-grpc-deferred.md): gRPC and the GAPIC clients wait for a std gRPC decision (Accepted, 2026-11-07)
- [0008](0008-license-and-hygiene.md): license and attribution for the BSD-3-Clause and Apache-2.0 sources, the trademark notice, the Azure repository's hygiene, local until approved (Accepted, 2026-11-07)
- [0009](0009-credentials.md): cloud.google.com/go/auth credentials in three Go-vectored steps (cache and metadata server, service account and authorized user files, Application Default Credentials); external accounts and impersonation later (Accepted, 2026-11-11)
- [0010](0010-storage.md): cloud.google.com/go/storage's REST client in four Go-vectored steps (client and metadata, reader/writer/copy, access and keys, bucket management); gRPC, metrics and parallel composite uploads later (Accepted, 2026-11-11)
