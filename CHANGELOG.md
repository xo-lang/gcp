# Changes

Changes to the root module (`github.com/xo-lang/gcp`: `auth`,
`gensupport`, `googleapi`, `option`) and the generator, newest first.
The API modules are generated; a generator change names the modules it
touches. Release notes: [docs/releases](docs/releases).

## Unreleased

- `auth`: the token cache (`cached`, Go's cachedTokenProvider with a
  225 second early refresh; Go's async refresh when given a task group,
  `CachedOptions.tasks`) and the metadata server's
  tokens (`compute`, `ComputeProvider`); decision 0009 step 1, checked
  against Go's auth v0.24.4 over a fake metadata server. `AuthErr`
  now displays Go's error text as is (no `auth: ` prefix added).
- `auth`: the JWT bearer grant of a service account (`two_legged`),
  the refresh token grant of a user (`refresh_token`, with Go's
  rotation, form and JSON responses and error texts), and Go's JWT
  layout (`encode_jws`, `parse_key`); decision 0009 step 2.
- `auth/credentials`: credentials from service_account and
  authorized_user files (`from_json`, `new_credentials_from_json`,
  `new_credentials_from_file`): self-signed JWTs (asked for, or for a
  universe other than googleapis.com), Go's project id and quota
  project rules (GOOGLE_CLOUD_PROJECT, GOOGLE_CLOUD_QUOTA_PROJECT) and
  universe domain. The other file types are later steps.
- `compute/metadata`: the metadata server client (Go's
  compute/metadata v0.10.0): `GCE_METADATA_HOST`, Go's headers and
  retries (5xx and 429, five retries), `project_id`, `universe_domain`.

## v0.1.0

The first tagged release: the root and all 667 API modules of
google.golang.org/api v0.311.0, tagged v0.1.0 at one commit (notes:
[docs/releases/v0.1.0.md](docs/releases/v0.1.0.md)).
