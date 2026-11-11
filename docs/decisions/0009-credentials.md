# 0009: Credentials (cloud.google.com/go/auth)

Status: Proposed (2026-11-11, drafted at the Xo Lead's request for the
owner's acceptance).

## Context

The [cloud.google.com/go coverage report](../reports/gcp-cloud-go-coverage.md)
ranks credentials as the top gap. All 667 google.golang.org/api modules
are Go-verified, but this repo's `auth` holds only `Token`,
`TokenProvider` and `StaticToken`. A program has to get an access token
some other way. Go's clients find one themselves through
`cloud.google.com/go/auth` v0.24.4 (Apache-2.0, Copyright Google LLC)
and `cloud.google.com/go/compute/metadata` v0.10.0. Decision
[0003](0003-hand-written-core.md) already places that hand-written code
here, and none of it needs gRPC.

What Go does (auth v0.24.4):

- `credentials.DetectDefault` (Application Default Credentials) takes,
  in order: credentials given as JSON or a file in the options; the file
  `GOOGLE_APPLICATION_CREDENTIALS` names; gcloud's well-known file
  (`$HOME/.config/gcloud/application_default_credentials.json`, or
  `%APPDATA%/gcloud/...` on Windows); then, on Google Cloud
  (`metadata.OnGCE`), the metadata server's tokens. Otherwise it fails
  with Go's error text.
- Credential files by `type` (internal/credsfile):
  - `service_account`: an RSA key that signs a JWT for the token
    endpoint's JWT bearer grant (`urn:ietf:params:oauth:grant-type:jwt-bearer`).
    With `UseSelfSignedJWT`, or a non-default universe domain, it is a
    self-signed JWT used as the token, with no request (selfsignedjwt.go).
  - `authorized_user`: a refresh token grant with the client id and
    secret.
  - `external_account`, `external_account_authorized_user`,
    `impersonated_service_account` and `gdch_service_account`: workload
    identity federation, impersonation, and Google Distributed Cloud.
- The metadata server: `GET http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token`
  (`GCE_METADATA_HOST` overrides the host) with `Metadata-Flavor: Google`,
  optional `scopes`. `OnGCE` checks `GCE_METADATA_HOST`, then races the
  metadata IP against a DNS lookup of `metadata.google.internal`, and on
  Linux also reads `/sys/class/dmi/id/product_name`. The project id comes
  from `project/project-id`.
- Every provider is wrapped in a cache (auth.go `cachedTokenProvider`).
  A token is refreshed 225 seconds before it expires
  (`defaultExpiryDelta`); in the async mode a stale token is returned
  while one refresh runs in the background.
- `Credentials` also carry the project id, the quota project
  (`quota_project_id` in the file, or `GOOGLE_CLOUD_QUOTA_PROJECT`) and
  the universe domain (`googleapis.com` by default).

## Decision (proposed)

Port, in three steps, to the existing `auth` module (one module, as Go's
package), each step checked against a Go program that runs auth v0.24.4
against fakes only:

1. **The cache and the metadata server.** `auth.cached(provider)` with
   Go's 225 second early expiry (the blocking mode first, then the async
   one); `auth.compute(...)` and `metadata` (OnGCE without the DMI read
   on a non-Linux OS, the token, project id and universe domain calls),
   with `GCE_METADATA_HOST`.
2. **Credential files.** `service_account` (the JWT bearer grant, RS256
   over std/crypto's `sign` and std/jwt; the self-signed JWT mode),
   `authorized_user` (the refresh token grant), and
   `credentials_from_json` and `credentials_from_file` with Go's type
   checks and error texts.
3. **`detect_default`**: Go's order (options, `GOOGLE_APPLICATION_CREDENTIALS`,
   the well-known file, the metadata server), the quota project and the
   universe domain, and `option.ClientOptions` taking the detected
   credentials when none are given.

Later steps, each with a record of its own: external accounts (the STS
exchange and the file, URL, executable, AWS and X.509 subject token
providers), impersonation, ID tokens, downscoping, GDCH, and the
certificate-based mTLS transport.

### Effects and capabilities

A provider names what it touches: `net` for the token endpoint and the
metadata server, `clock` for expiry, `rand` for the JWT's jti where Go
sets one, and `fs` and `env` only where `detect_default` reads the
environment and files. `credentials_from_json` takes bytes, so a program
that reads its key from elsewhere needs no `fs`.

### Verification

- Go vectors as for the generated modules ([0005](0005-verification.md)):
  a Go program runs auth v0.24.4 with an `http.Client` whose transport is
  a fake token endpoint and metadata server, and prints each request
  (method, URL, headers, the form or JWT claims after decoding) and each
  result or error text. The Xo tests replay the same cases over
  std/testing's FakeNet, FakeEnv and MemFs.
- The keys are invented test keys generated for the vectors. No real
  Google credentials, no network, and no file of the user's (neither
  `~/.config/gcloud` nor `%APPDATA%/gcloud`) are read by a test or an
  oracle: the oracle sets `HOME`, `APPDATA` and
  `GOOGLE_APPLICATION_CREDENTIALS` to a temporary directory.
- The JWT bearer grant's assertion is compared after decoding (its
  signature is checked with the public key), since RS256 signatures over
  `iat` differ by time. The fake clock fixes `iat` and `exp`.

## Consequences

- Every Go-verified module can authenticate with a service account key,
  a user's gcloud credentials, or the metadata server, as Go's clients
  do.
- The port of `cloud.google.com/go/storage` (the second gap) can follow
  on top of these credentials.
- Step 1's departures from Go (2026-11-11):
  - Go's async refresh hands out a stale token while a goroutine fetches
    the next one. Xo has no detached goroutine; the refresh needs a task
    that outlives the call. std's `task.Group.spawn_background` (core
    7.1) gives that when the caller hands the provider a group that lives
    as long as the program: `CachedOptions.tasks` (programs pass
    `os.tasks`). Without one, the cache refreshes before returning (Go's
    DisableAsyncRefresh). A library that wants Go's default without a
    group would need a std group owned by the program's main scope that
    any code can reach, which Xo does not have and should not
    (structured concurrency).
  - A metadata token body that is not JSON matches only Go's prefix
    (`credentials: invalid token JSON from metadata: `): the rest is
    encoding/json's own text (`unexpected EOF`), and std/json's differ.
    Matching them would need a table of encoding/json's messages in
    std/json (a std change), or here.
- Step 2's departures from Go (2026-11-11):
  - A private key that does not parse gives Go's prefix (`failed to
    parse private key. Tried PKCS8, PKCS1, and EC formats. Errors: [`)
    and std/crypto's reason, not Go's three encoding/asn1 errors; a
    credential file that is not JSON gives std/json's text, as in step 1.
  - A JWT bearer grant response's `id_token` does not move the token's
    expiry (Go reads its `exp`): Google returns one only for ID token
    requests, which are a later step.
  - Go caches an authorized_user's tokens twice (New3LOTokenProvider's
    cache inside fileCredentials'); here once, with the same refresh
    rule.
- Step 3's departures from Go (2026-11-11):
  - `on_gce` is not memoized per process (Go's sync.Once); a program
    that asks often keeps the answer.
  - Detected credentials reach a client through
    `credentials.client_options(creds, env)`, not inside
    `gensupport.new_client`: the client constructor takes only `Net`,
    and detection needs `Env`, `Fs` and `Clock` too, which a program
    passes once.
  - An OAuth client file (`web` or `installed`) gives Go's "auth handler
    must be specified" error; the three-legged flow with a handler is a
    later step.
- `auth` grows from 45 lines to an estimated 2,000 (Go's step 1 to 3
  sources are about 2,300 lines without tests).

## Alternatives

- **golang.org/x/oauth2/google** (the older package): Go's
  google.golang.org/api still accepts it, but new Go code uses
  cloud.google.com/go/auth, and google.golang.org/api v0.311.0's
  transports are built on it.
- **Leave credentials to the caller** (today's `StaticToken`): every
  program would hand-write the JWT grant or the metadata call.
