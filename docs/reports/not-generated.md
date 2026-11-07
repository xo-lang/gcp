# Not generated

What the generator leaves out on purpose, each with why. The generator
prints every item it does not handle (`not handled:` lines); this list
holds the ones that stay out by design rather than as a gap to close.

| Module | Method | Why |
| --- | --- | --- |
| discoveryengine/v1 | `discoveryengine.projects.locations.collections.dataConnector.mcp` | Its `extensions` query parameter is a repeated `object`. google-api-go-generator panics on that ("repeated fields of type message are prohibited as query parameters"), so Go's committed package predates this document and has no such method; nothing can be checked against Go. |
| discoveryengine/v1alpha | `discoveryengine.projects.locations.collections.dataConnector.mcp` | The same. |

## Gaps (to be generated)

- Media upload (91 methods) and media download (74 methods): their JSON
  calls are generated; the media paths are not yet.
- Pagers and the OAuth scope constants.
