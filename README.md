# Google Cloud for Xo

A community Google Cloud SDK for the Xo language. Not affiliated with or
endorsed by Google. Google Cloud is a trademark of Google LLC.

A port of Google's Go SDK for Google Cloud, starting with
google.golang.org/api's REST packages, generated from the Discovery
documents Go itself ships and checked against Go byte for byte.

Status (google.golang.org/api v0.311.0, 667 modules; the full table is
[docs/reports/gcp-go-coverage.md](docs/reports/gcp-go-coverage.md)):

- **Go-verified: 667 of 667.** Every method is called in Go and here
  with the same arguments against the same fake service, and the
  requests, the responses served and the decoded results are compared
  (34,228 vector tests, pagers, media upload and download among them),
  natively on darwin/arm64 and linux/arm64.
  discoveryengine/v1 and v1alpha are generated from the older document
  Go's package for them was built from (google.golang.org/api v0.293.0;
  see [not-generated.md](docs/reports/not-generated.md)).
- **Not ported yet: cloud.google.com/go** (206 modules: 724 GAPIC
  clients over gRPC, plus the hand-written bigquery, spanner, firestore
  and pubsub clients). The storage client is in progress (`storage`,
  [decision 0010](docs/decisions/0010-storage.md)'s four steps are
  done: metadata calls, listings, retries, reads, writes, copies and
  composes, signed URLs and POST policies, ACLs, HMAC keys,
  notifications, IAM, and lifecycle, retention, soft delete, autoclass,
  restore and move), the BigQuery client is in progress (`bigquery`,
  [decision 0011](docs/decisions/0011-bigquery.md) steps 1 to 4: the
  client, datasets, tables, routines, models, schemas, row values with
  NUMERIC and BIGNUMERIC, query parameters, queries, copy, extract and
  load jobs, job listing, the row iterator and streaming inserts; it
  needs Xo 0.50), and
  `auth` has decision 0009's credentials. See
  [gcp-cloud-go-coverage.md](docs/reports/gcp-cloud-go-coverage.md).

No real Google Cloud endpoint is called anywhere: every test runs
against local fakes. The records in
[docs/decisions](docs/decisions/README.md) were accepted by the owner.

## Install

Every module is tagged v0.1.0 (the first release, with Xo 0.46.0). Get
the API versions your program uses; each requires the root:

    xo get github.com/xo-lang/gcp@v0.1.0
    xo get github.com/xo-lang/gcp/storage/apiv1@v0.1.0

Requires Xo 0.51.0 or later (decision 0013's `as "-"` lists, xo decision 0622). Release notes:
[docs/releases/v0.1.0.md](docs/releases/v0.1.0.md).

## Empty values and null in a request

Every field is left out of a request body when it is empty, as in Go.
To send an empty value or `null` (a PATCH that removes every guest or a
Meet link), name the field in the model's `force_send_fields` or
`null_fields` (Go's ForceSendFields and NullFields, decision 0013):

```xo
let ev = calendar.Event{
  force_send_fields: [calendar.EventField.Attendees],
  null_fields: [calendar.EventField.ConferenceData],
}
// PATCH body: {"attendees":[],"conferenceData":null}
```

Nested models have their own lists (`EventReminders{force_send_fields:
[EventRemindersField.UseDefault]}` sends `"useDefault":false`). Only the
request body applies them: they are never in a model's own JSON
(`as "-"`, which needs xo 0.51.0 or later).

## Layout

- `auth`, `gensupport`, `googleapi`, `option`: the hand-written core.
- `<api>/apiv<version>`: one generated module per API version, at Go's
  package path with the version as `apivN` (`storage/apiv1` is Go's
  `storage/v1`; [decision 0012](docs/decisions/0012-apiv-paths.md)).
- `codegen`: the generator (`codegen/cmd/gen`) and the tool that derives
  its rows from Go's module (`codegen/gorows`).
- `scripts/gate.sh`: tests, type-checks, `xo fmt`, and regeneration;
  `scripts/check-public.sh` before any commit.
