# 0012: API versions are `apivN` path elements

Status: Accepted (2026-11-11, by the owner).

## Context

[0001](0001-scope-and-layout.md) put each generated module at Go's
package path under google.golang.org/api: `storage/v1`, `bigquery/v2`,
`drive/v3`. Xo reads a module path ending in `/vN` with N of 2 or more
as a semantic major version: such a module takes only `vN.x.y`
versions (XO1301). Every module is tagged v0.1.0, so
`require github.com/xo-lang/gcp/bigquery/v2 v0.1.0` fails, and with it
every generated module whose API version is `/v2` or above (91 of the
667). Inside this repository `xo.work` hid it; a user outside it could
not require them. The hand-written `bigquery` client
([0011](0011-bigquery.md) step 1) found it.

A Google API version is not a semver major version: `bigquery/v2` is the
API's name for its second REST surface, and its module starts at
v0.1.0 like every other.

## Decision

Every generated module's API version element is named `apiv` plus Go's
version, one rule for all 667, as cloud.google.com/go names its GAPIC
packages (`secretmanager/apiv1`):

| Go's package path (google.golang.org/api/...) | Module here (github.com/xo-lang/gcp/...) |
| --- | --- |
| `storage/v1` | `storage/apiv1` |
| `bigquery/v2` | `bigquery/apiv2` |
| `storage/v1beta1` | `storage/apiv1beta1` |
| `adexchangebuyer/v1.4` | `adexchangebuyer/apiv1.4` |
| `merchantapi/accounts/v1` | `merchantapi/accounts/apiv1` |
| `merchantapi/accounts_v1beta` | `merchantapi/accounts_apiv1beta` |

The rule is the generator's, not a hand edit: `codegen/gorows` writes
each row's `dir` (the module) and `go_dir` (Go's package path), and
`codegen/cmd/gen` and `codegen/cmd/govec` read Go's documents, Go's
code and Go's import path from `go_dir`. So every generated file but
`xo.mod` is unchanged by the rename, and its header still names Go's
path.

The old paths' tags (`storage/v1/v0.1.0`, ...) stay; tags are never
deleted. The new paths are tagged v0.1.0 once the full gate passes and
`scripts/check-public.sh` is clean (the owner approved those tags with
this decision), and a module outside the repository proves that a
renamed `/apiv2` module can be required.

## Consequences

- Breaking for users of the old paths: `use
  github.com/xo-lang/gcp/storage/v1` becomes `.../storage/apiv1`
  (CHANGELOG). The old tags still resolve for code that pins them.
- The hand-written `storage` and `bigquery` require `storage/apiv1` and
  `bigquery/apiv2` v0.1.0 (tagged 2026-11-11 on a5e2e72, with the 665
  other new paths). A module outside the repository requires
  `bigquery/apiv2` v0.1.0 with xo 0.48.2 and runs.
- The coverage report (`codegen/cmd/coverage`) names the new paths.

## Alternatives

- **Tag the `/vN` modules `vN.x.y`.** Works with XO1301, but `bigquery/v2
  v2.0.0` claims a major version history the module does not have, and
  `storage/v1` and `storage/v2` would follow different rules.
- **An Xo exemption for API-version paths.** A language rule bent for one
  repository's naming; other generated SDKs would need the same.
