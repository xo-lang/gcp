# 0011: BigQuery (cloud.google.com/go/bigquery)

Status: Accepted (2026-11-11, by the owner: rows through hand-written
`ValueLoader`/`ValueSaver` traits now; `derive BigQuery` is a later std
item, see Follow-ups).

## Context

The [cloud.google.com/go coverage report](../reports/gcp-cloud-go-coverage.md)
ranks `cloud.google.com/go/bigquery` third (1,924 importers), after
credentials ([0009](0009-credentials.md)) and Cloud Storage
([0010](0010-storage.md)), both done. Go's client is REST by default:
every call goes through `google.golang.org/api/bigquery/v2`, which this
repo already generates and Go-verifies (`bigquery/v2`).

bigquery v1.86.2 (Apache-2.0, Copyright Google LLC) has 13,388 lines in
its root package that are not tests:

- `bigquery.go`, `options.go`, `error.go`: `Client` (project, location,
  endpoints, the universe domain), retries and errors
- `dataset.go`, `table.go`, `routine.go`, `model.go`, `iam.go`: metadata,
  create, update (with etags), delete, listings, access entries, policies
- `schema.go`, `standardsql.go`: schemas, field types, the JSON schema
  form (`SchemaFromJSON`) and struct inference
- `value.go`, `nulls.go`, `params.go`, `intervalvalue.go`,
  `rangevalue.go`: row values to and from the API's JSON (including
  NUMERIC and BIGNUMERIC as `big.Rat`, DATE/TIME/DATETIME as
  `civil` types, INTERVAL, RANGE, JSON, GEOGRAPHY), the `Null*` types
  and query parameters
- `job.go`, `query.go`, `load.go`, `extract.go`, `copy.go`,
  `external.go`, `file.go`, `gcs.go`: jobs (insert, the `jobs.query`
  fast path and its fallback, polling, cancel, delete, listing),
  load/extract/copy configurations and external data
- `iterator.go`: the row iterator over `tabledata.list` and query
  results; `inserter.go`: streaming `insertAll`

It needs no gRPC except for three files: `storage_client.go`,
`storage_iterator.go` and `arrow.go` read results through the BigQuery
Storage Read API (gRPC and Apache Arrow), which Go uses only after
`EnableStorageReadClient`. The module's subpackages (`storage/` with
its managed writer, and the GAPIC clients `analyticshub`, `biglake`,
`connection`, `dataexchange`, `datapolicies`, `datatransfer`,
`migration`, `reservation`) are gRPC clients.

**gRPC flag:** the decision below needs no gRPC and does not depend on
[0007](0007-grpc-deferred.md). The Storage Read and Write APIs and the
GAPIC subpackages do; they are left to the GAPIC decision the coverage
report calls for, now that std has `std/grpc` and `std/protobuf`.

## Decision

Port the REST client as a module `github.com/xo-lang/gcp/bigquery` at
`bigquery/` (Go's package path; the generated `bigquery/v2` stays its
own module, required with the root module's `auth`, `option` and
`gensupport`), in four steps. Each step is checked against a Go program
that runs bigquery v1.86.2 against a local fake only. No real Google
project, dataset, credential or network is used by a test or an oracle.

1. **Client and metadata.** `new_client` (credentials through 0009's
   `detect_default`, the endpoint and universe domain options, the
   default location),
   datasets, tables, routines and models (get, create, update with
   etags, delete, listings), access entries and IAM, schemas and their
   JSON form, errors and retries.
2. **Values.** Row values to and from the API's JSON for every field
   type, the `Null*` types, query parameters (scalar, array, struct,
   range), INTERVAL and RANGE, and `ValueLoader`/`ValueSaver`.
3. **Queries and rows.** Query jobs (the `jobs.query` fast path, its
   fallback to `jobs.insert`, polling, dry runs, job statistics), the
   row iterator (`tabledata.list` and `getQueryResults`, page tokens,
   start index), and the streaming `Inserter` (`insertAll`, insert IDs,
   row errors as Go's `PutMultiError`).
4. **The other jobs.** Load (from Cloud Storage and from a reader),
   extract and copy, external data configurations, job listing, cancel
   and delete.

Not ported now, each with a record of its own later: the Storage Read
API path (`EnableStorageReadClient`, Arrow), the managed writer, the
GAPIC subpackages, and OpenTelemetry tracing (`trace.go`).

## Departures

- **No reflection.** Go loads rows into structs and infers schemas from
  them through `reflect` (183 uses, most in `value.go`, `schema.go` and `params.go`).
  Xo has none. Rows are `List[Value]` and `Map[Str, Value]` as in Go,
  and a user type loads or saves through the `ValueLoader`/`ValueSaver`
  traits, written by hand (the owner's choice, 2026-11-11). A `derive
  BigQuery` (as std has `derive SqlRow`) would restore Go's struct
  mapping and `InferSchema`; it is a later std item (Follow-ups), not
  part of this port.
- **NUMERIC and BIGNUMERIC** are std/big's `BigRat` (on xo main since
  9125f8fb5, Go's `big.Rat`). It is not in xo 0.48.2, so step 2 needs
  the next xo release. Go's `NumericString` and `BigNumericString`
  (`FloatString` with 9 and 38 digits) are `float_text(9)` and
  `float_text(38)`, and parsing is `big.parse_rat`.
- **Civil times** are std/time values with the field type saying which
  part counts (Go's `civil.Date`, `civil.Time`, `civil.DateTime`), or
  three small types of the module's own; step 2's oracle cases decide.

### Step 1 (client and metadata)

- **No project detection.** Go's `DetectProjectID` reads the project
  from the credentials; `new_client` takes it, and a caller passes
  `credentials.Credentials.project_id(env)`.
- **Handles hold references in access entries.** Go's `AccessEntry`
  holds a `*Table` or `*Routine`; here `TableRef` and `RoutineRef`
  (`table.ref()`), so an entry is a plain value with no client in it.
- **Go's optional types are `Option`s.** `optional.String` and friends
  in the `ToUpdate` types are `Str?`, `Bool?` and `Duration?`;
  `NeverExpire` is `Expiration.Never`.
- **Not in step 1:** `ExternalDataConfig` (step 4),
  `MaterializedViewDefinition.MaxStaleness` and the INTERVAL value it
  holds (step 2), and `Model.TrainingRuns`, which hands back the
  generated API's own types (a caller uses `bigquery/v2` directly).
- **`SchemaFromJSON`'s decode error** is std/json's text (`at $:
  expected array`), not encoding/json's.
- **`bigquery/v2` resolves through the workspace only.** `require
  github.com/xo-lang/gcp/bigquery/v2 v0.1.0` fails with XO1301 (a path
  ending in `/v2` takes only v2.x.y versions), though the tag exists;
  the same holds for every generated module whose API version is `/v2`
  or above (91 of them). `bigquery/xo.mod` requires the root module
  only until that is settled (Follow-ups).

The step's 44 cases run Go's client against a fake that records each
request; `bigquery/govec_test.xo` is generated from that output.

## Consequences

- Every step is Go-vectored, as 0009 and 0010 were; each records its
  departures here as it lands.
- `bigquery/v2` gains a hand-written caller; its generated surface does
  not change.
- NOTICE gains cloud.google.com/go/bigquery (Apache-2.0).

## Follow-ups

- **`derive BigQuery`** (std, later): derives `ValueLoader`,
  `ValueSaver` and a schema for a struct, as Go's reflection does
  (`InferSchema`, struct loading and saving). When it lands, the port
  gains Go's struct mapping without changing the traits.

- **`/vN` API modules and XO1301.** Google's API versions (`/v2`,
  `/v3`) are not semver majors, but Xo's rule reads them as such: either
  the generated modules are tagged `vN.x.y` under their path, or Xo
  exempts them, or the paths change. An owner decision; until then the
  hand-written modules resolve them through `xo.work`.

## Alternatives

- **The generated `bigquery/v2` alone.** It already works, but it leaves
  users to write the query fast path, polling, the row and value
  conversions and the inserter, which are the parts that make Go's
  client worth importing.
- **Wait for gRPC and port the Storage Read API too.** Faster reads of
  large results, but the REST path is Go's default and covers every
  call; Storage Read is an addition on top of it.
- **Firestore, Pub/Sub or Spanner next instead.** Each has more
  importers but is gRPC first; they wait for the GAPIC decision.
