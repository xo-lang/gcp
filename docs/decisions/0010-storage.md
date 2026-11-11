# 0010: Cloud Storage (cloud.google.com/go/storage)

Status: Accepted (owner, 2026-11-11, relayed by the Xo Lead; proposed
the same day at the Xo Lead's request).

## Context

The [cloud.google.com/go coverage report](../reports/gcp-cloud-go-coverage.md)
ranks `cloud.google.com/go/storage` second, after credentials
([0009](0009-credentials.md), Accepted). It has more importers than any
other module there (8,371). Go's default client is REST: `http_client.go`
over `google.golang.org/api/storage/v1`, which this repo already has
Go-verified (`storage/v1`). gRPC is opt-in (`NewGRPCClient`) and waits for
the std gRPC decision ([0007](0007-grpc-deferred.md)).

storage v1.70.0 (Apache-2.0, Copyright Google LLC) has 22,882 lines that
are not tests. About 12,000 of them make up the REST client:

- `storage.go`, `bucket.go`: `Client`, `BucketHandle`, `ObjectHandle`,
  their attrs and the conversions to and from `raw.Object`/`raw.Bucket`,
  conditions (generation and metageneration preconditions), listing
  iterators, `Composer`, signed URLs (`SignedURL`, V2 and V4)
- `http_client.go`: each call over `storage/v1`
- `reader.go`: ranged reads, decompressive transcoding, CRC32C and MD5
  checks, a reopen on a transient error mid-read
- `writer.go`: one-shot and resumable uploads, chunk size, checksums
- `copy.go`: `Copier` (rewrite with its token loop)
- `acl.go`, `iam.go`, `hmac.go`, `notifications.go`, `post_policy_v4.go`
- `invoke.go`, `option.go`: retries (`ShouldRetry`, idempotency by
  precondition, backoff), `x-goog-api-client` and `x-goog-gcs-idempotency-token`

The rest is gRPC (`grpc_*.go`, 7,500 lines), OpenTelemetry metrics and
tracing (`metrics.go`, `trace.go`), the bucket metadata cache, and
parallel composite uploads (`pcu.go`).

## Decision (proposed)

Port the REST client as a module `github.com/xo-lang/gcp/storage` at
`storage/` (Go's package path; the generated `storage/v1` stays a module
of its own, which it requires with the root module's `auth`, `option`
and `gensupport`), in four steps. Each step is checked against a Go
program that runs storage v1.70.0 against a local fake only:

1. **Client, handles and metadata.** `new_client` (credentials through
   0009's `detect_default`, `STORAGE_EMULATOR_HOST`, endpoints and the
   universe domain), bucket and object attrs (get, update, delete,
   create bucket), conditions, `objects`/`buckets` iterators with
   prefixes, delimiters, versions and match globs, `ErrObjectNotExist`
   and `ErrBucketNotExist`, and the retry rules of `invoke.go`.
2. **Data.** `Reader` (ranges, negative offsets, transcoding, checksum
   checks, the reopen), `Writer` (multipart and resumable over
   gensupport's media upload, chunk size and retry deadline, CRC32C and
   MD5), `Copier` and `Composer`.
3. **Access and keys.** ACLs, IAM policies, HMAC keys, notifications,
   `service_account`, signed URLs V2 and V4 and post policy V4 (signed
   with a service account key, as 0009's credentials hold it).
4. **The rest of bucket management.** Lifecycle, retention, soft delete,
   autoclass, hierarchical namespace, object retention, restore and move.

Not ported now, each with a record of its own later: the gRPC client,
metrics and tracing, the bucket metadata cache, parallel composite
uploads, and the experimental options.

### Effects and capabilities

Calls use `net` (and `clock` and `rand` for retries and the idempotency
token). Signing a URL needs only the key bytes and a time, so it takes
`clock` but no `net`. Nothing reads files except credential detection,
which is 0009's.

### Verification

- Go vectors as for the generated modules ([0005](0005-verification.md))
  and 0009: a Go program runs storage v1.70.0 with an `http.Client` whose
  transport is a fake JSON API and upload endpoint. It prints each request
  (method, URL with its query sorted, headers, body) and each result or
  error text. The Xo tests replay the same cases over std/testing's
  FakeNet.
- Signed URLs and post policies use invented test keys and a fixed time,
  so Go's output is compared byte for byte.
- No real Google project, bucket, credential or network is used by a test
  or an oracle.

- Step 1's departures from Go (2026-11-11):
  - The emulator host is `ClientOptions.emulator_host` (read with
    `emulator_host(env)`): `new_client` takes no `Env`.
  - A time the service leaves out is `None`, not Go's zero time.
  - Names that clash in Xo: `If` is `if_`, `BucketHandle.Name` is
    `bucket_name`, `UserProject` is `billed_to` (a field has the name).
  - Iterators' `next` gives `None` at the end (Go's iterator.Done).
  - `set_attr_selection` keeps the caller's order (Go writes a map's,
    which differs per run); the oracle's comparison sorts the list.
  - Go's check that an object name is valid UTF-8 has no case: an Xo
    `Str` always is. Its oracle case is not replayed.
- Step 2's departures from Go (2026-11-11):
  - `Writer` holds the data until `close` (Go streams it through a
    pipe as it is written), so `write` fails only after a failed or
    finished close. Go's `ChunkRetryDeadline` and `ProgressFunc` on
    `Writer` are not ported yet; chunks are retried by the client's
    retry settings.
  - `Copier.progress` is an optional function and
    `max_bytes_per_call` is public (Go's field is private, for its
    tests). `composer_from` takes a `List`.
  - `Client` has a test hook that cuts a read body short (FakeNet can
    serve no body that fails part way), to replay Go's reopen cases.
  - `gensupport` gained `Media.auto_checksum`, `crc32c_text`,
    `crc32c_of` and a public `resumable` with the last chunk's
    checksum. The generated `Objects.insert` does not yet add Go's
    automatic CRC32C (Go's generator special-cases that call); the
    `Writer` sends it itself.
- Step 3's departures from Go so far (signing, 2026-11-11):
  - `signed_url` and `generate_signed_post_policy_v4` take a `Clock`
    and a `Rand` (Go reads the system clock and crypto/rand), and a URL
    style's host does not read STORAGE_EMULATOR_HOST (pass `hostname`).
  - The bucket's signer comes from `ClientOptions.credentials_json`
    (Go reads its credentials' JSON); there is no GCE metadata lookup
    of the email. An IAM signing failure is `StorageErr.Invalid` with
    Go's text.
  - Two of Go's texts list a map in its random order: a bad method's
    error lists the methods sorted, and a policy's metadata conditions
    are sorted by name.
  - A bad private key's error is Xo's crypto text, not Go's asn1 text
    (that oracle case is not replayed).
  - Access (2026-11-11): Go's HMACKeyOption functions are one
    `HMACKeyOptions` value; ACL roles and entities, HMAC states and IAM
    roles are `Str` constants (`ROLE_READER`, `HMAC_ACTIVE`,
    `IAM_VIEWER`); iam.Policy and Policy3 are one `Policy` (a v3 handle
    sends version 3); a time the service leaves out of an HMAC key is
    `None`, not Go's zero time.

## Consequences

- A Go program's storage calls port almost line for line, using the most
  common Google Cloud client.
- `storage/v1` stays the generated surface, and this module sits on top of
  it as Go's does.
- Step 1 can start at once. Steps 2 to 4 each add a module version and a
  CHANGELOG entry.

## Alternatives

- **Generated `storage/v1` only:** a program then builds uploads, reads
  and retries itself. That is what Go users avoid by using this client.
- **Port the gRPC client too:** it waits for 0007.
