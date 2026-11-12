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
   extract and copy, external data configurations and job listing
   (cancel and delete came with step 3).

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
  9125f8fb5, Go's `big.Rat`), first released in xo 0.49.1, so the
  bigquery module needs xo 0.49.1 or later (step 2b). Go's `NumericString` and `BigNumericString`
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
- **A loader is an interface used as a generic bound.** Go's
  `ValueLoader` fills its receiver in `Load`; here `ValueLoader` has
  `fn load(var self, ...)` (decision 0613 step 4, Xo 0.50) and
  `RowIterator.next_into[T: ValueLoader](var dst: T)` fills the
  caller's value. Interface values of it (a loader kept in a field)
  wait for decision 0613 step 5; until then a loader is not stored, and
  `next_with` takes a function `fn(List[Value], Schema) -> T ! BqErr`
  (as Xo 0.49 required). `[]Value` is the row itself and
  `map[string]Value` is `ValueMap` (or `load_map`). `ValueSaver` is an
  interface, and `ValuesSaver` is Go's; `row_json` is the JSON a
  streaming insert sends (encoding/json's: keys sorted, `<>&` escaped,
  NaN refused).
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
- **NUMERIC and BIGNUMERIC cells were an error** until step 2b
  (`bigquery: NUMERIC values need std/big's BigRat`); step 2b reads
  them.

The step's 42 cases (`bigquery/value_test.xo`, its lines in
`value_want_test.xo`, generated by the oracle's `gen_want.py` with the
departures above put in) run Go's conversions over a fake
`tabledata.list`, `ValuesSaver.Save` and its JSON, IntervalValue, the
civil strings, the Null types' JSON, String and decoding, and the
`queryParameters` of a fake `jobs.query`.

### Step 3 (queries, jobs, rows and streaming inserts)

- **A query is a value with two parts**: `Query.config` is Go's
  `QueryConfig` and `Query.id` its `JobIDConfig` (Go embeds both). Go's
  fast path is kept: `read` sends `jobs.query` when the configuration
  allows (no destination, dispositions, legacy SQL, partitioning,
  clustering, encryption, schema updates, timeout, continuous, job id,
  or a priority other than interactive), and keeps the answer's rows as
  the first page; else it runs a job and reads its results. As in Go,
  the fast path sends the query's own location, not the client's, and
  a default dataset only when it names a dataset.
- **A destination is a `TableRef`** (Go's `*Table`), so a
  configuration needs no client.
- **Jobs are values.** `status` and `wait` take `var self`: they return
  the status and keep it as `last_status`, as Go's do through the
  pointer. `config` is a `JobConfig` enum: `Query`, or `Other` (the raw
  configuration) until step 4 ports copy, extract and load. Cancel and
  delete are here, not in step 4. A failed job is a done status whose
  `err` is set, as in Go; Go's `Error` is `ServiceError` (`Error` is
  Xo's prelude interface).
- **Polling pauses are client options**: `query_poll` (Go's
  waitForQuery, 50 ms growing by 1.3 to 60 s) and `status_poll` (Go's
  Wait of a non-query job, gax's default 1 s by 2 to 30 s), so tests
  run them short, as `backoff` already was.
- **Rows come one at a time**: `next` (a row's values, Go's `[]Value`),
  `next_map` (Go's `map[string]Value`) and `next_with(load)` (a loader
  function; see step 2a). `page_size` is Go's `PageInfo().MaxSize`.
  Go fetches a table's schema and its first page at once; here the
  schema is asked for first, and the list's error wins as in Go. The
  oracle's fake puts Go's two requests in that order.
- **Streaming inserts take `List[ValueSaver]`**, Go's `Put` of a slice
  of savers; a struct (Go's reflection) waits for `derive BigQuery`.
  Row errors are `BqErr.PutMulti` with Go's `PutMultiError` text.
- **Random ids** (job ids, insert ids) are 32 hex digits from the
  client's `Rand`, and a `jobs.query` request id is Go's
  `request-YYYYMMDD-<ns>-0001` from its `Clock`; the oracle and the
  tests compare them as `RANDOMID` and `REQUESTID`.
- **Not here yet**: a read job's parameters back from the service (Go's
  `bqToQueryParameter`; `config` gives none), `TableDefinitions`
  (external data, step 4), the query plan, timeline, BI Engine,
  performance insights, script, transaction and reservation usage
  statistics, `Job.Children` and the job listing (step 4), and the
  client option `WithDefaultJobCreationMode` (the query's own
  `job_creation_mode` is here).

The step's 43 cases (`bigquery/jobs_test.xo`, generated by the
oracle's `gen_jobs_test.py` from its output; printing helpers in
`jobs_fake_test.xo`) cover `jobs.insert` with every query option, the
refusals, dry runs, the job retry reasons, the fast path (one page, two
pages, incomplete then polled, no job, maps), the job path, job
metadata, status, statistics, wait (query and load), cancel and delete,
`tabledata.list` pages, start index and page size, and the inserter's
bodies, insert ids, row errors and retries.

### Step 4 (copy, extract and load jobs, job listing)

- **Copier, Extractor and Loader** are values like Query: `config` is
  Go's `CopyConfig`, `ExtractConfig` or `LoadConfig` and `id` its
  `JobIDConfig`. `Table.copier_from`, `Table.extractor_to`,
  `Model.extractor_to` and `Table.loader_from` build them; `run` starts
  the job. A fetched job's `config()` is `JobConfig.Copy`, `Extract`,
  `Load` or `Query`, checked in Go's order.
- **A load's source is an enum** (`LoadSource.Gcs` or `Reader`, Go's
  `LoadSource` interface). A reader's bytes go with the request through
  gensupport's media upload (multipart under the chunk size, resumable
  above it) and the call is not retried, as Go's `insertJob` with media;
  a `GCSReference` load is retried as any job. `MediaOptions` stands for
  Go's `googleapi.MediaOption` list.
- **`quote` can be sent as ""**: the generator now ports Go's
  `emptyPattern`, so a string field with a default whose pattern
  matches "" is optional, as Go's `*string`. Only bigquery's two
  `quote` fields (pattern `.?`) change among the 667 modules;
  `CSVOptions.force_zero_quote` sends "" as Go's `ForceZeroQuote`.
- **`Client.jobs()`** is Go's `JobIterator`: project, all users, state,
  creation time range and parent job, listed with projection full and
  retried as a read; `Job.children()` lists in the client's project, as
  Go does.

- **External data** (step 4d): `ExternalDataConfig` with its options
  as an enum (`ExternalDataConfigOptions`: Avro, Csv, Json,
  GoogleSheets, Bigtable, Parquet; Go's interface), on
  `TableMetadata`, `TableMetadataToUpdate` and a query's
  `table_definitions` (`ExternalData.Config` or `.Gcs`, Go's
  `ExternalData`). A Bigtable column's `qualifier` is `Bytes`, as Go's
  string holds any bytes: sent as text when UTF-8, else unpadded
  base64. `table_definitions` is `Map?`: `Some` (even empty) takes the
  job path, as Go's non-nil map; a fetched table or job whose qualifier
  is bad base64 is an error, as in Go.

The step's 30 cases (`bigquery/copy_test.xo`, generated by the
oracle's `gen_jobs4_test.py`) cover copy with every option and each
operation type, extract of a table and a model, load from Cloud Storage
with every load and file option, the zero quote, a reader's multipart
upload and its refusal to retry, config round trips of fetched jobs,
the listing's pages, filters, retries and errors, and external data on
table create, get and update and in query table definitions.

### Step 5 (Xo 0.50: loaders and Schema?)

Xo 0.50 fixes the false XO0407 alias cycle on a `Schema?` field (xo
955837e2c), so `FetchedPage`, `FileConfig` and `ExternalDataConfig`
hold `Schema?` again in place of `List[FieldSchema]?` (the same type;
no caller changes). `ValueLoader` becomes an interface with a `var
self` method, `ValueMap` implements it, and `next_into` loads a row into
any implementer (`loader_test.xo` checks the write-back through a
generic bound; the oracle cases that read rows as maps now go through
`next_into(ValueMap)`).

### Step 2b (NUMERIC and BIGNUMERIC)

- **`Value.Rat` and `Param.Rat`** hold std/big's `BigRat` (Go's
  `*big.Rat`). Cells parse with `big.parse_rat` (Go's `SetString`,
  so `1/3`, `0x10` and `1e3` read as Go reads them; the error is Go's
  `bigquery: invalid NUMERIC value "abc"`).
- **Writing**: a streaming insert sends a NUMERIC field's value as
  `numeric_string` and a BIGNUMERIC field's as `big_numeric_string`;
  a parameter is NUMERIC with `numeric_string`, also inside an explicit
  BIGNUMERIC parameter, as Go does (its comment: a `big.Rat` cannot say
  its scale).
- **The bigquery module needs xo 0.49.1** (the first release with
  BigRat).

The step's 5 cases join `value_test.xo` (the oracle's `bigqueryvals`):
cells of both types, Go's rounding of `FloatString(9)` and `(38)`, a
saver's JSON with repeated values and nulls, and the parameters.

## Consequences

- Every step is Go-vectored, as 0009 and 0010 were; each records its
  departures here as it lands.
- `bigquery/apiv2` gains a hand-written caller; its generated surface
  changes only where the generator now matches Go (the two `quote`
  fields, step 4).
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
