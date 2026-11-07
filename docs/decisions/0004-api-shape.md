# 0004: Go's service and call shape, in Xo style

Status: Proposed (for the owner's approval, through the lead).

## Context

Go's generated packages expose `NewService(ctx, opts...)`, a field per
resource (`svc.Objects`), a method per Discovery method returning a call
builder (`svc.Objects.List(bucket)`), optional parameters as builder
methods (`.Prefix("a").MaxResults(10)`), `.Fields(...)`, `.Header()`,
`.Context(ctx)`, and `.Do(opts...)`; list methods add `.Pages(ctx, f)`;
media methods add `.Media(r)`, `.ResumableMedia(...)` and
`.Download()`.

## Decision

- Keep Go's tree: a service, its resources (nested as in Discovery), a
  function per method, Go's names in Xo casing.
- A method takes its required parameters (path, then required query, in
  Go's order) and an options struct holding every optional parameter,
  `fields` and extra headers, with defaults; it returns the result or a
  typed error. Builders are not used: Xo's named, defaulted options are
  the idiom the AWS and Azure ports use.
- List methods also get a pager (`next_page`, `more`) built on the
  core's page iteration; media methods take their body as Bytes or a
  reader, with Go's upload choice (multipart below Go's chunk size,
  resumable above).
- The requests are byte for byte Go's: method, URL with its query in
  Go's order, headers, body; a shape change never changes a request.

## Consequences

- The vector programs call Go's builders by reflection and record the
  requests; the Xo side calls the function with the same values, so the
  shape difference stays out of the comparison.

## Alternatives

- Builders as in Go: closer in form, but every optional parameter would
  be a method on a call struct, and Xo's options structs already carry
  the same information with defaults.
