# cloud.google.com/go coverage

Go's Google Cloud SDK has two halves. `google.golang.org/api` (the REST
clients generated from discovery documents) is covered by
[gcp-go-coverage.md](gcp-go-coverage.md): all 667 API versions of
v0.311.0 are Go-verified. This report covers the other half,
`cloud.google.com/go` (as of 2026-11-11): the GAPIC clients generated
from protobuf service definitions and the hand-written clients (storage,
bigquery, spanner, firestore, pubsub, auth, ...).

## Summary

- 206 modules (208 `go.mod` files in googleapis/google-cloud-go main,
  without the two test-only modules). 198 hold GAPIC clients, 724 clients
  in all (`apivN` packages). None is ported: decision
  [0007](../decisions/0007-grpc-deferred.md) defers gRPC clients until
  Xo's std has gRPC.
- For 124 of those modules, the same service's REST surface is already
  Go-verified here through google.golang.org/api (`secretmanager/v1`,
  `pubsub/v1`, `spanner/v1`, ...). The other 72 have no discovery
  document of their own.
- Hand-written clients (19 modules with hand-written code; lines below
  count non-test, non-generated `.go` files of the latest version):
  spanner 37,498, storage 25,570, bigquery 18,217, firestore 15,178,
  bigtable 10,198, auth 6,678, pubsub 6,515, datastore 6,314.
- Xo's std now has `std/grpc` (gRPC over std/http's HTTP/2),
  `std/protobuf`, `std/protojson`, `std/protodesc`, `std/protowkt` and
  `xo proto gen`, which is what decision 0007 waited for. A new decision
  here would choose how the GAPIC surface is generated.

## Top gaps, ranked

1. **Credentials (`cloud.google.com/go/auth`).** This repo's `auth` is a
   static token only. There are no Application Default Credentials
   (`GOOGLE_APPLICATION_CREDENTIALS`, the gcloud well-known file),
   service account keys (the JWT bearer grant and self-signed JWTs),
   authorized user refresh tokens, external accounts (workload identity
   federation) or the metadata server's tokens (`compute/metadata`,
   imported by 2,750 packages, 1,333 lines, no gRPC). Every one of the
   667 Go-verified modules needs a token from somewhere. Decision 0003
   already places this hand-written code here; it needs no gRPC.
2. **`cloud.google.com/go/storage`** (imported by 8,371 packages, the
   most of any module here). Its default transport is REST
   (`http_client.go` over `google.golang.org/api/storage/v1`, which is
   Go-verified here); gRPC is opt-in (`NewGRPCClient`). Its 25,570
   hand-written lines (object readers and resumable writers, retries,
   ACLs, signed URLs, post policies, HMAC keys, notifications) can be
   ported over our `storage/v1` without gRPC.
3. **`cloud.google.com/go/bigquery`** (1,924 importers): REST by default
   over `bigquery/v2` (Go-verified here); the Storage Read and Write
   APIs are gRPC and would wait.
4. **The gRPC clients**: pubsub (3,528 importers), firestore (3,233),
   datastore (1,577), spanner (1,455), longrunning (1,249), logging
   (1,147), secretmanager/apiv1 (954), bigtable (843). These need the
   GAPIC decision first.

Imported by: pkg.go.dev's "Imported by" count for the package
(2026-11-11), fetched for the modules named above only.

## Method

- Modules: every `go.mod` in googleapis/google-cloud-go's main tree
  (GitHub API, recursive), without `internal`, `third_party`, `testing`
  and example modules, and without `spanner/benchmarks` and
  `spanner/test/...`.
- Versions: proxy.golang.org `@latest`.
- GAPIC clients: the `apivN` directories of a module.
- Hand-written lines: the latest version's proxy zip, `.go` files outside
  `apivN`, `*pb`, `internal`, `testdata`, `cmd` and test directories,
  without `_test.go` files and files whose header says `Code generated`.
  Measured for the 19 modules with three or more such files in the tree.
- Transport: a hand-written client imports `google.golang.org/api/<api>`
  (REST) or `google.golang.org/grpc`.
- "REST surface Go-verified": this repo has a module under the same
  first path element (`secretmanager/v1` for `secretmanager`).

## Modules

| Go module (cloud.google.com/go/...) | latest | GAPIC clients | hand-written lines | imported by | our port |
| --- | --- | --- | --- | --- | --- |
| (root) | v0.123.0 | 1 | 3460 |  | not ported (gRPC, decision 0007) |
| accessapproval | v1.15.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `accessapproval/...` is Go-verified |
| accesscontextmanager | v1.17.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `accesscontextmanager/...` is Go-verified |
| advisorynotifications | v1.12.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `advisorynotifications/...` is Go-verified |
| agentidentity | v0.3.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `agentidentity/...` is Go-verified |
| agentplatform | v0.23.0 |  | 11617 |  | not ported |
| agentregistry | v0.4.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `agentregistry/...` is Go-verified |
| ai | v1.3.1 | 8 |  |  | not ported (gRPC, decision 0007) |
| aiplatform | v1.127.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `aiplatform/...` is Go-verified |
| alloydb | v1.33.1 | 9 |  |  | not ported (gRPC, decision 0007); the REST surface `alloydb/...` is Go-verified |
| analytics | v0.38.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `analytics/...` is Go-verified |
| apigateway | v1.17.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `apigateway/...` is Go-verified |
| apigeeconnect | v1.14.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| apigeeregistry | v1.2.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `apigeeregistry/...` is Go-verified |
| apihub | v1.3.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `apihub/...` is Go-verified |
| apikeys | v1.10.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `apikeys/...` is Go-verified |
| apiregistry | v1.2.1 | 4 |  |  | not ported (gRPC, decision 0007) |
| appengine | v1.17.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `appengine/...` is Go-verified |
| apphub | v1.4.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `apphub/...` is Go-verified |
| appoptimize | v0.7.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| apps | v1.4.1 | 8 |  |  | not ported (gRPC, decision 0007) |
| apptopology | v0.4.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| area120 | v0.17.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| artifactregistry | v1.28.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `artifactregistry/...` is Go-verified |
| asset | v1.30.1 | 6 |  |  | not ported (gRPC, decision 0007) |
| assuredworkloads | v1.21.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `assuredworkloads/...` is Go-verified |
| auditmanager | v1.7.0 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `auditmanager/...` is Go-verified |
| auth | v0.24.4 |  | 6678 | 136 | a static token only (gcp `auth`); no ADC, service account, user or metadata credentials |
| auth/oauth2adapt | v0.3.1 |  |  |  | not ported |
| automl | v1.23.1 | 4 |  |  | not ported (gRPC, decision 0007) |
| backstory | v0.2.0 |  |  |  | not ported |
| backupdr | v1.20.0 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `backupdr/...` is Go-verified |
| baremetalsolution | v1.12.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `baremetalsolution/...` is Go-verified |
| batch | v1.24.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `batch/...` is Go-verified |
| beyondcorp | v1.11.1 | 10 |  |  | not ported (gRPC, decision 0007); the REST surface `beyondcorp/...` is Go-verified |
| biglake | v1.6.1 | 6 |  |  | not ported (gRPC, decision 0007); the REST surface `biglake/...` is Go-verified |
| bigquery | v1.86.2 | 19 | 18217 | 1,924 | not ported; its REST transport sits on our bigquery/v2 (Go-verified) |
| bigquery/v2 | v2.0.0-20261111025851-991cd5c14cdb | 3 | 593 |  | not ported (gRPC, decision 0007); the REST surface `bigquery/...` is Go-verified |
| bigtable | v1.58.0 | 2 | 10198 | 843 | not ported (gRPC, decision 0007) |
| billing | v1.28.1 | 6 |  |  | not ported (gRPC, decision 0007) |
| binaryauthorization | v1.18.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `binaryauthorization/...` is Go-verified |
| capacityplanner | v0.9.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| certificatemanager | v1.17.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `certificatemanager/...` is Go-verified |
| ces | v1.7.0 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `ces/...` is Go-verified |
| channel | v1.29.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| chat | v1.11.0 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `chat/...` is Go-verified |
| chronicle | v1.6.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| cloudbuild | v1.37.0 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `cloudbuild/...` is Go-verified |
| cloudcontrolspartner | v1.12.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `cloudcontrolspartner/...` is Go-verified |
| clouddms | v1.16.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| cloudprofiler | v1.2.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `cloudprofiler/...` is Go-verified |
| cloudquotas | v1.14.1 | 4 |  |  | not ported (gRPC, decision 0007) |
| cloudsecuritycompliance | v1.3.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| cloudtasks | v1.21.1 | 6 |  |  | not ported (gRPC, decision 0007); the REST surface `cloudtasks/...` is Go-verified |
| commerce | v1.11.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| commerceproducer | v0.7.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| compute | v1.75.0 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `compute/...` is Go-verified |
| compute/metadata | v0.10.0 |  | 1333 | 2,750 | not ported; needs no gRPC |
| confidentialcomputing | v1.20.1 | 4 |  |  | not ported (gRPC, decision 0007) |
| config | v1.15.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `config/...` is Go-verified |
| configdelivery | v1.3.1 | 4 |  |  | not ported (gRPC, decision 0007) |
| contactcenterinsights | v1.26.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `contactcenterinsights/...` is Go-verified |
| container | v1.56.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `container/...` is Go-verified |
| containeranalysis | v0.21.1 | 3 |  |  | not ported (gRPC, decision 0007); the REST surface `containeranalysis/...` is Go-verified |
| datacatalog | v1.35.1 | 8 |  |  | not ported (gRPC, decision 0007); the REST surface `datacatalog/...` is Go-verified |
| dataflow | v0.18.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `dataflow/...` is Go-verified |
| dataform | v1.9.0 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `dataform/...` is Go-verified |
| datafusion | v1.16.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `datafusion/...` is Go-verified |
| datalabeling | v0.17.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `datalabeling/...` is Go-verified |
| datamanager | v1.9.0 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `datamanager/...` is Go-verified |
| dataplex | v1.39.0 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `dataplex/...` is Go-verified |
| dataproc | v1.12.0 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `dataproc/...` is Go-verified |
| dataqna | v0.15.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| datastore | v1.28.1 | 3 | 6314 | 1,577 | not ported (gRPC, decision 0007); the REST surface `datastore/...` is Go-verified |
| datastream | v1.24.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `datastream/...` is Go-verified |
| deploy | v1.35.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| designcenter | v0.1.0 | 2 |  |  | not ported (gRPC, decision 0007) |
| developerconnect | v1.4.0 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `developerconnect/...` is Go-verified |
| developerknowledge | v0.6.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `developerknowledge/...` is Go-verified |
| devicestreaming | v1.3.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| dialogflow | v1.89.1 | 8 |  |  | not ported (gRPC, decision 0007); the REST surface `dialogflow/...` is Go-verified |
| discoveryengine | v1.38.0 | 6 |  |  | not ported (gRPC, decision 0007); the REST surface `discoveryengine/...` is Go-verified |
| dlp | v1.39.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `dlp/...` is Go-verified |
| documentai | v1.52.0 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `documentai/...` is Go-verified |
| domains | v0.18.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `domains/...` is Go-verified |
| edgecontainer | v1.12.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| edgenetwork | v1.11.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| errorreporting | v0.11.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| essentialcontacts | v1.14.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `essentialcontacts/...` is Go-verified |
| eventarc | v1.27.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `eventarc/...` is Go-verified |
| filestore | v1.18.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| financialservices | v1.3.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| firestore | v1.29.2 | 1 | 15178 | 3,233 | not ported (gRPC, decision 0007); the REST surface `firestore/...` is Go-verified |
| ftp | v0.3.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `ftp/...` is Go-verified |
| functions | v1.27.1 | 6 | 191 |  | not ported (gRPC, decision 0007) |
| geminidataanalytics | v1.9.0 | 4 |  |  | not ported (gRPC, decision 0007) |
| gkebackup | v1.16.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `gkebackup/...` is Go-verified |
| gkeconnect | v1.2.1 | 4 |  |  | not ported (gRPC, decision 0007) |
| gkehub | v0.24.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `gkehub/...` is Go-verified |
| gkemulticloud | v1.15.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| gkerecommender | v1.2.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| grafeas | v0.6.1 | 1 |  |  | not ported (gRPC, decision 0007) |
| gsuiteaddons | v1.14.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| hypercomputecluster | v1.4.0 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `hypercomputecluster/...` is Go-verified |
| iam | v1.15.1 | 11 |  | 600 | not ported (gRPC, decision 0007); the REST surface `iam/...` is Go-verified |
| iap | v1.19.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `iap/...` is Go-verified |
| identitytoolkit | v1.2.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `identitytoolkit/...` is Go-verified |
| ids | v1.13.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `ids/...` is Go-verified |
| iot | v1.15.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| kms | v1.37.0 | 4 |  |  | not ported (gRPC, decision 0007) |
| language | v1.20.1 | 6 |  |  | not ported (gRPC, decision 0007); the REST surface `language/...` is Go-verified |
| licensemanager | v1.3.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| lifesciences | v0.18.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `lifesciences/...` is Go-verified |
| locationfinder | v1.2.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| logging | v1.21.1 | 2 | 2806 | 1,147 | not ported (gRPC, decision 0007); the REST surface `logging/...` is Go-verified |
| longrunning | v1.5.0 |  | 1985 | 1,249 | not ported |
| lustre | v1.3.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| maintenance | v1.2.1 | 4 |  |  | not ported (gRPC, decision 0007) |
| managedidentities | v1.15.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `managedidentities/...` is Go-verified |
| managedkafka | v1.3.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `managedkafka/...` is Go-verified |
| maps | v1.45.0 | 24 |  |  | not ported (gRPC, decision 0007) |
| mediatranslation | v0.15.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| memcache | v1.19.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `memcache/...` is Go-verified |
| memorystore | v1.9.0 | 4 |  |  | not ported (gRPC, decision 0007) |
| metastore | v1.22.1 | 6 |  |  | not ported (gRPC, decision 0007); the REST surface `metastore/...` is Go-verified |
| migrationcenter | v1.9.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `migrationcenter/...` is Go-verified |
| modelarmor | v1.6.0 | 4 |  |  | not ported (gRPC, decision 0007) |
| monitoring | v1.32.1 | 6 |  |  | not ported (gRPC, decision 0007); the REST surface `monitoring/...` is Go-verified |
| netapp | v1.21.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `netapp/...` is Go-verified |
| networkconnectivity | v1.30.1 | 6 |  |  | not ported (gRPC, decision 0007); the REST surface `networkconnectivity/...` is Go-verified |
| networkmanagement | v1.34.0 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `networkmanagement/...` is Go-verified |
| networksecurity | v0.21.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `networksecurity/...` is Go-verified |
| networkservices | v1.8.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `networkservices/...` is Go-verified |
| notebooks | v1.20.1 | 6 |  |  | not ported (gRPC, decision 0007); the REST surface `notebooks/...` is Go-verified |
| observability | v0.1.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `observability/...` is Go-verified |
| optimization | v1.14.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| oracledatabase | v1.8.0 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `oracledatabase/...` is Go-verified |
| orchestration | v1.19.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| orgpolicy | v1.22.1 | 3 |  |  | not ported (gRPC, decision 0007); the REST surface `orgpolicy/...` is Go-verified |
| osconfig | v1.24.1 | 10 |  |  | not ported (gRPC, decision 0007); the REST surface `osconfig/...` is Go-verified |
| oslogin | v1.20.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `oslogin/...` is Go-verified |
| parallelstore | v1.3.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `parallelstore/...` is Go-verified |
| parametermanager | v1.2.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `parametermanager/...` is Go-verified |
| phishingprotection | v0.15.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| policysimulator | v1.3.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `policysimulator/...` is Go-verified |
| policytroubleshooter | v1.18.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `policytroubleshooter/...` is Go-verified |
| privatecatalog | v0.18.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| privilegedaccessmanager | v1.3.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| productregistry | v0.3.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| profiler | v0.7.1 |  | 968 |  | not ported |
| pubsub | v1.52.0 | 1 | 6515 | 3,528 | not ported (gRPC, decision 0007); the REST surface `pubsub/...` is Go-verified |
| pubsub/v2 | v2.9.0 | 1 | 4858 | 382 | not ported (gRPC, decision 0007); the REST surface `pubsub/...` is Go-verified |
| pubsublite | v1.10.0 | 1 | 4063 |  | not ported (gRPC, decision 0007); the REST surface `pubsublite/...` is Go-verified |
| rapidmigrationassessment | v1.9.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `rapidmigrationassessment/...` is Go-verified |
| recaptchaenterprise | v1.3.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `recaptchaenterprise/...` is Go-verified |
| recommendationengine | v0.17.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `recommendationengine/...` is Go-verified |
| recommender | v1.21.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `recommender/...` is Go-verified |
| redis | v1.29.0 | 6 |  |  | not ported (gRPC, decision 0007); the REST surface `redis/...` is Go-verified |
| resourcemanager | v1.18.1 | 4 |  |  | not ported (gRPC, decision 0007) |
| retail | v1.37.1 | 6 |  |  | not ported (gRPC, decision 0007); the REST surface `retail/...` is Go-verified |
| run | v1.25.0 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `run/...` is Go-verified |
| saasplatform | v0.13.0 | 4 |  |  | not ported (gRPC, decision 0007) |
| scheduler | v1.18.1 | 4 |  |  | not ported (gRPC, decision 0007) |
| secretmanager | v1.24.0 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `secretmanager/...` is Go-verified |
| securesourcemanager | v1.13.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `securesourcemanager/...` is Go-verified |
| security | v1.29.1 | 6 |  |  | not ported (gRPC, decision 0007) |
| securitycenter | v1.49.1 | 10 |  |  | not ported (gRPC, decision 0007); the REST surface `securitycenter/...` is Go-verified |
| securitycentermanagement | v1.8.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| securityposture | v1.3.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `securityposture/...` is Go-verified |
| servicecontrol | v1.20.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `servicecontrol/...` is Go-verified |
| servicedirectory | v1.19.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `servicedirectory/...` is Go-verified |
| servicehealth | v1.9.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| servicemanagement | v1.18.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `servicemanagement/...` is Go-verified |
| serviceusage | v1.16.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `serviceusage/...` is Go-verified |
| shell | v1.15.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| shopping | v1.19.0 | 58 |  |  | not ported (gRPC, decision 0007) |
| spanner | v1.96.1 | 5 | 37498 | 1,455 | not ported (gRPC, decision 0007); the REST surface `spanner/...` is Go-verified |
| speech | v1.38.1 | 6 |  |  | not ported (gRPC, decision 0007); the REST surface `speech/...` is Go-verified |
| sql | v0.7.0 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `sql/...` is Go-verified |
| storage | v1.70.0 | 2 | 25570 | 8,371 | not ported; its REST transport sits on our storage/v1 (Go-verified) |
| storagebatchoperations | v1.3.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `storagebatchoperations/...` is Go-verified |
| storageinsights | v1.10.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| storagetransfer | v1.21.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `storagetransfer/...` is Go-verified |
| streetview | v1.3.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| support | v1.16.1 | 4 |  |  | not ported (gRPC, decision 0007) |
| talent | v1.16.1 | 4 |  |  | not ported (gRPC, decision 0007) |
| telcoautomation | v1.9.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| texttospeech | v1.24.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `texttospeech/...` is Go-verified |
| tpu | v1.16.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `tpu/...` is Go-verified |
| trace | v1.18.1 | 4 |  |  | not ported (gRPC, decision 0007) |
| translate | v1.20.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `translate/...` is Go-verified |
| vectorsearch | v1.7.0 | 4 |  |  | not ported (gRPC, decision 0007) |
| vertexai | v0.19.0 |  | 9968 |  | not ported |
| video | v1.36.0 | 6 |  |  | not ported (gRPC, decision 0007) |
| videointelligence | v1.19.1 | 6 |  |  | not ported (gRPC, decision 0007); the REST surface `videointelligence/...` is Go-verified |
| vision | v1.2.0 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `vision/...` is Go-verified |
| visionai | v1.4.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| vmmigration | v1.18.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `vmmigration/...` is Go-verified |
| vmwareengine | v1.11.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `vmwareengine/...` is Go-verified |
| vpcaccess | v1.16.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `vpcaccess/...` is Go-verified |
| webrisk | v1.19.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `webrisk/...` is Go-verified |
| websecurityscanner | v1.14.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `websecurityscanner/...` is Go-verified |
| workflows | v1.22.1 | 8 |  |  | not ported (gRPC, decision 0007); the REST surface `workflows/...` is Go-verified |
| workloadidentity | v0.3.1 | 2 |  |  | not ported (gRPC, decision 0007) |
| workloadmanager | v1.3.1 | 2 |  |  | not ported (gRPC, decision 0007); the REST surface `workloadmanager/...` is Go-verified |
| workstations | v1.10.1 | 4 |  |  | not ported (gRPC, decision 0007); the REST surface `workstations/...` is Go-verified |
