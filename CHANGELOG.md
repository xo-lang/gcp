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
- `compute/metadata`: the metadata server client (Go's
  compute/metadata v0.10.0): `GCE_METADATA_HOST`, Go's headers and
  retries (5xx and 429, five retries), `project_id`, `universe_domain`.

## v0.1.0

The first tagged release: the root and all 667 API modules of
google.golang.org/api v0.311.0, tagged v0.1.0 at one commit (notes:
[docs/releases/v0.1.0.md](docs/releases/v0.1.0.md)).
