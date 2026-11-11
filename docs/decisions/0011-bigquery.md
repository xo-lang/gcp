# 0011: BigQuery (cloud.google.com/go/bigquery)

Status: Proposed (2026-11-11, at the Xo Lead's request; for the owner).

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

## Decision (proposed)

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

## Departures to decide with the owner

- **No reflection.** Go loads rows into structs and infers schemas from
  them through `reflect` (183 uses, most in `value.go`, `schema.go` and `params.go`).
  Xo has none. Rows are `List[Value]` and `Map[Str, Value]` as in Go,
  and a user type loads or saves through the `ValueLoader`/`ValueSaver`
  traits, written by hand. A `derive BigQuery` (as std has `derive
  SqlRow`) would restore Go's struct mapping and `InferSchema`; that is
  a std request to the Xo Lead, not part of this port. This is the
  one question for the owner here.
- **NUMERIC and BIGNUMERIC** are std/big's `BigRat` (on xo main since
  9125f8fb5, Go's `big.Rat`). It is not in xo 0.48.2, so step 2 needs
  the next xo release. BigRat has no `FloatString`, which Go's
  `NumericString` and `BigNumericString` use (9 and 38 digits); the port
  writes that rounding over `num()` and `denom()` with Go's
  round-half-away-from-zero, checked by step 2's oracle cases.
- **Civil times** are std/time values with the field type saying which
  part counts (Go's `civil.Date`, `civil.Time`, `civil.DateTime`), or
  three small types of the module's own; step 2's oracle cases decide.

## Consequences

- Every step is Go-vectored, as 0009 and 0010 were; each records its
  departures here as it lands.
- `bigquery/v2` gains a hand-written caller; its generated surface does
  not change.
- NOTICE gains cloud.google.com/go/bigquery (Apache-2.0).

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
