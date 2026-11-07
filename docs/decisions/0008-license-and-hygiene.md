# 0008: License, attribution and hygiene

Status: Proposed (for the owner's approval, through the lead).

## Context

The sources ported are google.golang.org/api (BSD-3-Clause, Copyright
Google Inc.) and cloud.google.com/go/auth (Apache-2.0, Copyright Google
LLC). The AWS and Azure ports are MIT with attribution to their MIT and
Apache sources.

## Decision

- The project's license is the owner's choice; proposed: MIT, as the
  AWS and Azure ports, with a NOTICE that names both Google sources,
  their licenses and copyright lines, and keeps the BSD-3-Clause and
  Apache-2.0 texts that their terms require for derived work (the
  generator's naming rules, the core's ported logic, the Discovery
  documents' descriptions in generated docs).
- A trademark notice: Google Cloud and its product names are Google's
  trademarks; the project is not affiliated with or endorsed by Google.
- Hygiene as in the Azure repository: no project IDs, service account
  emails, keys, tokens, bucket names, IP addresses, the owner's
  hostnames or paths under `/Users`, and no emails other than the
  commit author's; generated documentation's example emails rewritten
  to example.com by the generator; gitleaks over the full history and
  the public-content check before every push.
- The repository stays local until the owner approves publishing.

## Consequences

- The NOTICE and the hygiene checks are in the first commit with code.

## Alternatives

- Apache-2.0 for the whole project: simpler compliance with one
  source, but different from the other two ports.
