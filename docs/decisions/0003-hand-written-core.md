# 0003: The hand-written core is auth and transport, as in Go

Status: Proposed (for the owner's approval, through the lead).

## Context

The owner's rule from the Azure port: new features are generated, not
hand-maintained; hand-written code stays only where Go hand-writes it
too. In Go that is `cloud.google.com/go/auth` (credentials, token
sources, the HTTP transport's auth) and google.golang.org/api's
`internal/gensupport`, `googleapi` and `option`.

## Decision

Hand-written, in the root module, each ported from Go's source with Go's
behavior and error text:

- auth:
  - Application Default Credentials, in Go's order (`detect.go`): the
    `GOOGLE_APPLICATION_CREDENTIALS` file, the gcloud well-known file,
    then the metadata server (`compute.go`);
  - the credential files Go reads (`filetypes.go`): `service_account`
    (OAuth 2.0 JWT bearer, and the self-signed JWT Go prefers when no
    scopes are set or a universe domain applies), `authorized_user`
    (refresh token), and later `external_account` (workload identity
    federation) and `impersonated_service_account`, each by a slice
    with its vectors;
  - the metadata server client (`Metadata-Flavor: Google`, its paths,
    Go's retries and timeouts);
  - token caching and refresh timing: waits for the std token cache
    decision the Azure port is also waiting for; until then each
    credential keeps its token as Go's does, in its own struct.
- transport (`gensupport`, `googleapi`, `option`): request building
  (`alt=json`, `prettyPrint=false`, `fields`, the `x-goog-api-client`
  and User-Agent headers), Go's retry policy (`retry.go`: which
  statuses and errors retry, the backoff), media upload (multipart and
  resumable, chunk sizes as Go's), media download, `googleapi.Error`
  with its details, and page iteration (`nextPageToken`).
- Every generated module uses only this core; nothing service-specific
  is hand-written, unless Go hand-writes it in its package (none: in
  v0.293.0 every API package's only non-test Go file is its generated
  `-gen.go`).

## Consequences

- The core's correctness is checked by its own vectors against Go
  (JWT bytes with a fixed key and clock, token request bodies, the
  metadata server requests, retry sequences, upload sessions), before
  any generated module depends on it.
- The token cache's std decision gates only the caching layer, not the
  first slice.

## Alternatives

- Wrap golang.org/x/oauth2 semantics instead of cloud.google.com/go/auth:
  google.golang.org/api moved to the latter, and its behavior (self-signed
  JWT, universe domains) is what the generated clients see.
