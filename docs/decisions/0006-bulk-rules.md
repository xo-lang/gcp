# 0006: Bulk rules from the start

Status: Proposed (for the owner's approval, through the lead).

## Context

The Azure port added generation of every module late, after hand-tuned
early modules, and then had to remove per-module customization that the
generator could derive. Here the bulk comes first.

## Decision

- Every API version Go ships is generated from the first generator
  commit on; the first gate builds all of them, and the coverage report
  lists each as Go-verified, compiled or not generated.
- Per-API customization lives only in data the generator reads, and is
  derived from Go's module (its package path, version and document);
  none is written by hand. A failure is fixed once in the generator,
  with a full regeneration diff of every module, never by editing one
  module.
- `scripts/refresh.sh` (the Azure script's design) moves every module
  to Go's newest release, regenerates, writes and runs the vector
  programs, and prints each module's result, so a new failure class
  shows as one list; `--verify` runs the batched differentials (about
  25 modules a job, on the offload hosts).
- Each batch reports its pass and fail counts by failure class, and the
  coverage report's three counts.
- One heavy job at a time on the Mac; large jobs on the offload hosts;
  the Go backend's memory per module is measured and recorded (the
  largest Azure module's test package peaked at 10 GB).

## Consequences

- The generator's first version is larger (it must take every Discovery
  feature at least to "compiled"), and the order of work is by failure
  class, not by API.

## Alternatives

- One API at a time, by hand-picked priority: what made the Azure
  port's late cleanup necessary.
