# 0014: Credential discovery in modules of its own (gcp, aws, azure)

Status: Accepted (owner, 2026-11-14, through the lead): the rule holds
for gcp, aws and azure; gcp v0.3.0 and aws v0.3.0 are the breaking
releases that carry it; aws's SessionCache and retrieve go into the root
`aws` package (Go's layout) unless the effects gate shows that widens
the root, in which case `aws/credcache`, with the reason recorded here.
Proposed 2026-11-13 by aws-43 for the lead.

## Context

Xo records effects per module (decision 0156 of xo): `xo.lock` holds
one effects line per required module, the union of what any package
of that module may reach. A program accepts that line when it adds or
upgrades the module, whatever packages it actually uses.

scarlet-03 (google-workspace-mcp) moved to gcp v0.2.0 and had to
accept `env` and `fs.read` for the gcp root module, though the server
passes its own token and never detects credentials. Both effects come
from `auth/credentials` (Application Default Credentials: credential
files, `GOOGLE_APPLICATION_CREDENTIALS`, gcloud's well-known file) and
`compute/metadata` (`GCE_METADATA_HOST`), added after v0.1.0 in the
root module.

Measured with xo 0.51.0 on 2026-11-13: an app that `xo get`s the
modules, its `xo.lock` effects lines.

| SDK | Module | Effects |
| --- | --- | --- |
| gcp v0.1.0 | root | clock, net.dial, rand |
| gcp v0.2.0 | root | clock, **env, fs.read**, net.dial, rand |
| gcp v0.2.0 | calendar/apiv3 | clock, net.dial, rand |
| aws v0.2.x | root | clock, **env, fs, net.dial, proc**, rand |
| aws v0.2.0 | service/s3, service/sts | clock, net.dial, rand |
| azure v0.1.0 | root | clock, net.dial, rand |
| azure v0.1.0 | azidentity | clock, env, fs.read, net.dial, net.listen, proc, rand |

So a Calendar program accepts `env` and `fs.read` and an S3 program
accepts `env`, `fs` (`config` and `credentials` only read files and
test that they exist, `fs.read_text` and `fs.exists`, which the lock
shows as the whole family) and `proc` (`credential_process`), all for
code it may never call. azure already has the layout this decision asks for: azidentity
is its own module, as in Go, and its root stays at the network, clock
and randomness a request needs.

Go's own SDKs draw the same line: `github.com/aws/aws-sdk-go-v2/config`
and `.../credentials` are modules apart from the root
(`aws.Credentials` and `aws.CredentialsCache` stay in it);
`cloud.google.com/go/auth` and `cloud.google.com/go/compute/metadata`
are modules apart from `google.golang.org/api`;
`github.com/Azure/azure-sdk-for-go/sdk/azidentity` is apart from
`azcore`.

## Decision

One rule for every Xo cloud SDK: **a root module (and every generated
API module) reaches only what a request needs: `net.dial`, `clock`,
`rand`. Code that discovers credentials or configuration from the
environment, files, processes or a local listener is a module of its
own**, at the directory it has today, as Go's SDKs place it.

- **gcp**: `auth/credentials` and `compute/metadata` become modules
  (`github.com/xo-lang/gcp/auth/credentials`,
  `github.com/xo-lang/gcp/compute/metadata`), each requiring the root.
  `auth` (the TokenProvider interface, the token cache, the static
  provider, the JWT and refresh grants, which take their inputs as
  values) stays in the root. `auth.compute` (the metadata server's
  tokens) moves with `compute/metadata` if it reaches `env`, else
  stays.
- **aws**: `credentials` (its providers and chain, and `container`,
  `imds`, `ssocreds`, `stscreds` under it) and `config` become modules.
  What the 400-odd services use today, `SessionCache`,
  `new_session_cache`, `retrieve` and `header_value` (S3 Express
  session credentials and the static provider), moves into the root
  `aws` package, as Go keeps `aws.Credentials` and
  `aws.CredentialsCache` in its root. No service module then requires
  `credentials`.
- **azure**: no change. It is the reference layout.
- Each SDK's gate checks the rule: the root's and every generated
  module's effects are exactly `clock,net.dial,rand` (from `xo audit
  --json` of a probe app), so a later change cannot widen them
  silently.

## Migration

- **Import paths do not change.** The new modules sit at the
  directories the packages have today, so `use
  github.com/xo-lang/gcp/auth/credentials` and `use
  github.com/xo-lang/aws/config` keep their text. What changes is
  xo.mod: a program that uses them adds a require (`xo get
  github.com/xo-lang/gcp/auth/credentials@v0.3.0`, or `xo mod tidy`;
  the implementation checks that tidy finds the new module and that a
  missing require fails with an error naming the `xo get` to run).
- **aws services**: code that names `credentials.SessionCache` or
  `credentials.retrieve` names `aws.` instead. That is generated and
  internal code; user programs that hand a provider to a client keep
  building once they require `credentials`.
- **No shim alias.** A re-export of the moved packages from the root
  would make the root require the new module, which requires the root
  (a module cycle), and the root's effects line would again be the
  union, which is the problem this decision removes. The old
  packages' tags stay as they are; nothing is deleted.
- **Versions.** gcp v0.3.0 and aws v0.3.0, every module at one version
  (each SDK's release script tags root and modules together), with a
  CHANGELOG entry and release notes that list the requires to add.
  Pre-1.0, a minor version may break (the Go semver rule Xo follows);
  `xo publish`'s XO1310 effect check is about adding effects in a
  compatible release, and this one removes them.

## Consequences

- A program that only calls APIs with a token it holds accepts
  `clock,net.dial,rand` for every SDK module it requires; one that
  detects credentials accepts the wider set for exactly the
  credentials module, where `xo audit` shows it by name.
- One more require for the common case (ADC on gcp, the default
  config chain on aws). Go programs make the same choice with the same
  modules.
- The gates gain the effects check, which also catches any future
  widening of a generated module.

## Owner's answers (2026-11-14)

1. Yes, for all three SDKs, with gcp v0.3.0 and aws v0.3.0.
2. The root `aws` package, unless the effects gate shows it widens the
   root; then `aws/credcache`, noted here.
