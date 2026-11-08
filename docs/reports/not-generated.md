# Not generated

What the generator leaves out on purpose, each with why. The generator
prints every item it does not handle (`not handled:` lines); this list
holds the ones that stay out by design rather than as a gap to close.

| Module | Method | Why |
| --- | --- | --- |
| (none) | | |

discoveryengine/v1 and v1alpha used to be listed here: v0.311.0's
document adds `dataConnector.mcp`, whose `extensions` query parameter is
a repeated `object`, and google-api-go-generator panics on that
("repeated fields of type message are prohibited as query parameters"),
so Go's package kept the code it generated from v0.293.0's document
(revision 20260322; the code is byte for byte the same in both
releases). Their rows now take that document (`doc_version`, written by
codegen/gorows when a document lists calls its Go code lacks), so the
modules and Go share their input and nothing is left out.

## Gaps (to be generated)

- The OAuth scope constants (Go's `CloudPlatformScope` and the like).
  Media upload and download and the pagers are generated
  (decision 0004's addendum, 2026-11-07).
