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
repo already generates and Go-verifies (`bigquery/apiv2`, [0012](0012-apiv-paths.md)).

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
`bigquery/` (Go's package path; the generated `bigquery/apiv2` stays its
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
  generated API's own types (a caller uses `bigquery/apiv2` directly).
- **`SchemaFromJSON`'s decode error** is std/json's text (`at $:
  expected array`), not encoding/json's.
- **`bigquery/v2` resolved through the workspace only.** `require
  github.com/xo-lang/gcp/bigquery/v2 v0.1.0` failed with XO1301 (a path
  ending in `/v2` takes only v2.x.y versions), as for every generated
  module whose API version is `/v2` or above (91 of them). Settled by
  [0012](0012-apiv-paths.md): the module is `bigquery/apiv2`.

The step's 44 cases run Go's client against a fake that records each
request; `bigquery/govec_test.xo` is generated from that output.

### Step 2a (values; NUMERIC and BIGNUMERIC wait for step 2b)

- **`Value` is an enum.** Go's `Value` is `any`; here `Value` has one
  variant per kind Go hands back (`Null`, `Str` for STRING, GEOGRAPHY
  and JSON, `Bytes`, `Int`, `Float`, `Bool`, `Timestamp`, `Date`,
  `Time`, `DateTime`, `Interval`, `Range`), `List` for both a repeated
  field and a record's values (Go's `[]Value` for both), and `Map` for a
  record by name (Go's `map[string]Value`).
- **Civil times are std/time's** `Date` and `ClockTime`, and the
  module's `DateTime{date, time}` (std has no date and time pair without
  a zone). Settles the open question above.
- **A loader is a function.** Go's `ValueLoader` fills its receiver in
  `Load`; an Xo interface method cannot change its receiver (no `var
  self`), so a loader is `fn(List[Value], Schema) -> T ! BqErr` that
  step 3's row iterator calls. `[]Value` is the row itself and
  `map[string]Value` is `load_map`. `ValueSaver` is an interface, and
  `ValuesSaver` is Go's; `row_json` is the JSON a streaming insert
  sends (encoding/json's: keys sorted, `<>&` escaped, NaN refused).
- **Parameters say their type.** Go infers a parameter's type from its
  Go type by reflection; here `Param` has a variant per type, an
  `Array` names its element type (as Go's slice type does, so an empty
  one has a type), a `Struct` lists its fields in order, `Null(type_)`
  is Go's invalid Null types, and `Explicit` is Go's
  `*QueryParameterValue`. `QueryParameter.to_json` is the API's
  `queryParameters` entry, byte for byte. Not representable, so not
  ported: nil, `uint64` and map parameters (Go's errors).
- **The `Null*` types keep Go's JSON** through `derive Json(via:
  json.Value, ...)` (decision 0478 of xo): null when not valid,
  NullFloat64's NaN and infinities as strings, NullTime and NullDateTime
  as BigQuery writes them. `display` is Go's String, and `param()` is the
  parameter Go infers from each. Go's `NullJSON` is `NullJson`. A decode
  error is std/json's text, not encoding/json's.
- **TIMESTAMP holds the years 1677 to 2262.** A Time is nanoseconds in
  an Int; Go's time.Time holds the years 1 to 9999. A cell outside is an
  error naming the range (`-62135596800000000`, 0001-01-01, in the
  oracle). A TIMESTAMP parameter is written in UTC (Go writes a
  time.Time in its own zone; the same instant).
- **Go bugs not ported**, each shown by an oracle case:
  `IntervalValue.String` writes a negative fraction as `6.-00001` (here
  `6.000001`) and drops the sign of a part under a year or an hour
  (`0-5` for minus five months; here `-0-5`, and `ParseInterval` keeps
  it); `ToDuration` multiplies the sub-second nanoseconds by 1e9 in an
  int32 (1 s + 1 ns gives 2 s, 0.5 s gives -0.74 s; here 1000000001 and
  500000000 ns); `CivilTimeString` writes a time within half a
  microsecond of the next second with seven digits (`.1000000`; here
  `.999999`); a streaming insert sends an INTERVAL as the Go struct's
  fields (`{"Years":1,...}`; here its string, as BigQuery reads it).
- **Errors from Go's strconv** keep Go's text (`strconv.ParseInt:
  parsing "1.5": invalid syntax`); those from Go's time and base64
  packages are std's or the module's own (`bigquery: bad DATE value`).
- **NUMERIC and BIGNUMERIC cells are an error** until step 2b
  (`bigquery: NUMERIC values need std/big's BigRat`), which lands with
  the first xo release holding std/big's BigRat.

The step's 42 cases (`bigquery/value_test.xo`, its lines in
`value_want_test.xo`, generated by the oracle's `gen_want.py` with the
departures above put in) run Go's conversions over a fake
`tabledata.list`, `ValuesSaver.Save` and its JSON, IntervalValue, the
civil strings, the Null types' JSON, String and decoding, and the
`queryParameters` of a fake `jobs.query`.

## Consequences

- Every step is Go-vectored, as 0009 and 0010 were; each records its
  departures here as it lands.
- `bigquery/apiv2` gains a hand-written caller; its generated surface does
  not change.
- NOTICE gains cloud.google.com/go/bigquery (Apache-2.0).

## Follow-ups

- **`derive BigQuery`** (std, later): derives `ValueLoader`,
  `ValueSaver` and a schema for a struct, as Go's reflection does
  (`InferSchema`, struct loading and saving). When it lands, the port
  gains Go's struct mapping without changing the traits.


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
