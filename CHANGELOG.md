# Changes

Changes to the root module (`github.com/xo-lang/gcp`: `auth`,
`gensupport`, `googleapi`, `option`) and the generator, newest first.
The API modules are generated; a generator change names the modules it
touches. Release notes: [docs/releases](docs/releases).

## Unreleased

- **Feature** (decision 0013): a request body can send empty values and
  null. Every model a request can hold has `force_send_fields` and
  `null_fields` (Go's ForceSendFields and NullFields), typed by a
  generated enum of its fields (`EventField.Attendees`), and
  `gensupport.json_body` applies them at every level:
  `Event{force_send_fields: [EventField.Attendees]}` sends
  `{"attendees":[]}`, `Event{null_fields: [EventField.ConferenceData]}`
  sends `{"conferenceData":null}`. The lists are never in a model's own
  JSON (`as "-"`), so gcp now needs xo 0.51.0 or later (xo decision
  0622). Every generated module changes.
- bigquery needs Xo 0.50: `ValueLoader` is an interface (`load(var
  self, ...)`, Go's), `ValueMap` implements it and
  `RowIterator.next_into` loads a row into any implementer; schema
  fields are `Schema?` again (decision 0011 step 5).
- **Breaking** (decision 0012): every generated module's API version is
  now an `apivN` path element, one generator rule for all 667, so Xo
  does not read `/v2` as a semver major (XO1301 made the 91 modules at
  `/v2` and above impossible to require). Rename your `use` and
  `xo get` paths:

  | Old (Go's package path) | New |
  | --- | --- |
  | `github.com/xo-lang/gcp/storage/v1` | `github.com/xo-lang/gcp/storage/apiv1` |
  | `github.com/xo-lang/gcp/bigquery/v2` | `github.com/xo-lang/gcp/bigquery/apiv2` |
  | `github.com/xo-lang/gcp/<api>/v1beta1` | `github.com/xo-lang/gcp/<api>/apiv1beta1` |
  | `github.com/xo-lang/gcp/<api>/v1.4` | `github.com/xo-lang/gcp/<api>/apiv1.4` |
  | `github.com/xo-lang/gcp/merchantapi/accounts_v1beta` | `github.com/xo-lang/gcp/merchantapi/accounts_apiv1beta` |

  `codegen/services.toml` gains `go_dir` (Go's path) beside `dir` (the
  module); generated files other than `xo.mod` are unchanged. The old
  paths keep their v0.1.0 tags.
- `bigquery` (decision 0011 step 2b): NUMERIC and BIGNUMERIC.
  `Value.Rat` and `Param.Rat` (std/big's `BigRat`), `numeric_string`,
  `big_numeric_string`; cells parse as Go's `Rat.SetString`. The
  bigquery module now needs Xo 0.49.1. 5 Go oracle cases.
- `bigquery` (decision 0011 step 4): copy, extract and load jobs and
  job listing. `Copier` (`Table.copier_from`), `Extractor`
  (`Table.extractor_to`, `Model.extractor_to`), `Loader`
  (`Table.loader_from` a `LoadSource.Gcs` or `Reader`), `GCSReference`,
  `FileConfig`, `CSVOptions`, `JobConfig.Copy`, `Extract` and `Load`,
  `Client.jobs()` and `Job.children()`, and external data
  (`ExternalDataConfig` and its options on tables and as a query's
  `table_definitions`). 30 Go oracle cases.
- Generator: Go's `emptyPattern` (a string with a default whose pattern
  matches "" is optional, as Go's `*string`). Touches `bigquery/apiv2`
  only: `CsvOptions.quote` and `JobConfigurationLoad.quote` are `Str?`.
- `bigquery` (decision 0011 step 3): queries and rows. `Query`
  (`QueryConfig`, `JobIdConfig`; `run` as a job, `read` over the
  `jobs.query` fast path or the job's results), `Job` (`job_from_id`,
  `job_from_id_location`, `job_from_project`, `status`, `wait`, `read`,
  `config`, `cancel`, `delete`), `JobStatus` and `JobStatistics` (query,
  load and extract details), `RowIterator` (`Table.read`, page tokens,
  `start_index`, `page_size`, `next`, `next_map`, `next_with` a loader),
  and the streaming `Inserter` (`put`, insert ids, `BqErr.PutMulti` of
  `RowInsertionError`, `ServiceError`). 43 Go oracle cases.
- `bigquery` (decision 0011 step 2a): row values. `Value` (every field
  type but NUMERIC and BIGNUMERIC, which wait for std/big's BigRat),
  `DateTime`, `RangeValue`, `IntervalValue` (`parse_interval`,
  `display`, `canonicalize`, `to_duration`, `interval_from_duration`),
  `load_map`, `ValueSaver` and `ValuesSaver`, `row_json`,
  `civil_time_string` and `civil_date_time_string`, and query
  parameters (`QueryParameter`, `Param`, `QueryParameterValue`,
  `to_json`), and the `Null*` types (`NullInt64` ... `NullDateTime`,
  Go's JSON forms through `derive Json(via:)`). 42 Go oracle cases; Go's interval and civil string bugs
  are not ported (decision 0011).
- `bigquery` (decision 0011 step 1): a hand-written client over
  `bigquery/v2`: `new_client`, datasets, tables, routines and models
  (metadata, create, update with an etag, delete, listings), access
  entries, table IAM policies, schemas (`relax`, `to_json_fields`,
  `schema_from_json`), errors and Go's retries. 44 Go oracle cases.
- `storage`: the fields decision 0010's steps left out: the bucket
  encryption enforcement configs (`EncryptionEnforcementConfig`), object
  contexts (`ObjectContexts`, on attributes, updates and writes) and
  `Query.filter`. 11 Go oracle cases.
- `storage` (decision 0010 step 4): lifecycle rules, retention
  policies (`lock_retention_policy`), soft delete, autoclass, the
  hierarchical namespace, custom placement, object retention
  (`set_object_retention`, `override_unlocked_retention`), soft-deleted
  objects (`soft_deleted`, `restore`) and `move`. 20 Go oracle cases.
- `storage` (decision 0010 step 3, access): bucket, default object and
  object ACLs (`acl`, `default_object_acl`), HMAC keys
  (`create_hmac_key`, `hmac_key_handle`, `list_hmac_keys`),
  notifications (`add_notification`, `notifications`,
  `delete_notification`) and IAM policies (`iam`, `v3`, `Policy` with
  Go's Add and Remove order). 33 Go oracle cases.
- `storage` (decision 0010 step 3, signing): `signed_url` (V2 and V4)
  and `generate_signed_post_policy_v4`, with an RSA key or a signer,
  Go's URL styles, headers and query parameters, and the bucket's
  `signed_url` and `generate_signed_post_policy_v4`, which take the
  signer from `ClientOptions.credentials_json` or sign with the IAM
  Credentials API. 35 Go oracle cases at a fixed time.
- `storage` (decision 0010 step 2): `Reader` over the XML API (ranges,
  negative offsets, `read_compressed`, Go's CRC32C check, the reopen
  after a body cut short, `ObjectNotExist` and `Checksum` errors),
  `Writer` (one multipart request when the data fits a chunk, else a
  resumable session; Go's auto CRC32C, `send_crc32c`, MD5, chunk size
  0 with the service's checksum checked), `Copier` (rewrite with its
  token and progress) and `Composer`. 50 more cases replay the Go
  oracle (65 in all over FakeNet).
- `gensupport`: `Media.auto_checksum`, `crc32c_text` and `crc32c_of`,
  and `resumable` is public with the last chunk's checksum
  (`X-Goog-Hash: crc32c=...`), as Go's storage sends it.
- `storage` (new module `github.com/xo-lang/gcp/storage`, decision 0010
  step 1): Go's Cloud Storage client over the JSON API: `new_client`
  (endpoint, STORAGE_EMULATOR_HOST), bucket and object handles with
  `attrs`, `update`, `delete`, bucket `create`, `Conditions` and
  `BucketConditions` with Go's error texts, object and bucket listings
  (`Query`, `set_attr_selection`), `ErrObjectNotExist` and
  `ErrBucketNotExist` (`is_object_not_exist`, `is_bucket_not_exist`),
  and Go's retries (policy, gax backoff, max attempts, invocation id
  and idempotency token). 28 cases replay the Go oracle's requests and
  results line for line over FakeNet.
- `auth`: the token cache (`cached`, Go's cachedTokenProvider with a
  225 second early refresh; Go's async refresh when given a task group,
  `CachedOptions.tasks`) and the metadata server's
  tokens (`compute`, `ComputeProvider`); decision 0009 step 1, checked
  against Go's auth v0.24.4 over a fake metadata server. `AuthErr`
  now displays Go's error text as is (no `auth: ` prefix added).
- `auth`: the JWT bearer grant of a service account (`two_legged`),
  the refresh token grant of a user (`refresh_token`, with Go's
  rotation, form and JSON responses and error texts), and Go's JWT
  layout (`encode_jws`, `parse_key`); decision 0009 step 2.
- `auth/credentials`: credentials from service_account and
  authorized_user files (`from_json`, `new_credentials_from_json`,
  `new_credentials_from_file`): self-signed JWTs (asked for, or for a
  universe other than googleapis.com), Go's project id and quota
  project rules (GOOGLE_CLOUD_PROJECT, GOOGLE_CLOUD_QUOTA_PROJECT) and
  universe domain. The other file types are later steps.
- `auth/credentials`: `detect_default` (Application Default
  Credentials, decision 0009 step 3): Go's order (the options' JSON or
  file, GOOGLE_APPLICATION_CREDENTIALS, gcloud's well-known file, the
  metadata server on Google Cloud) and Go's not-found text;
  metadata credentials take their project id and universe domain (read
  once) from the server; `client_options` puts detected credentials and
  their quota project into `option.ClientOptions`.
- `compute/metadata`: `on_gce` (GCE_METADATA_HOST, or Go's race of the
  HTTP and DNS probes with the DMI product name check).
- `compute/metadata`: the metadata server client (Go's
  compute/metadata v0.10.0): `GCE_METADATA_HOST`, Go's headers and
  retries (5xx and 429, five retries), `project_id`, `universe_domain`.

## v0.1.0

The first tagged release: the root and all 667 API modules of
google.golang.org/api v0.311.0, tagged v0.1.0 at one commit (notes:
[docs/releases/v0.1.0.md](docs/releases/v0.1.0.md)).
