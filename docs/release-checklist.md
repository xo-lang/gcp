# Release checklist

The first release (v0.1.0) and the steps for it. The owner tags and
publishes; nothing here tags the real repository without
`scripts/first-release.sh --push`.

1. **Requires.** Every API module requires the root at the release
   version and nothing else. `scripts/first-release.sh v0.1.0` (a dry
   run) checks them and prints the tags. codegen is not published.
2. **Versions.** `gensupport.VERSION` (the User-Agent) is the release
   version without its `v`, and CHANGELOG.md has its section.
3. **Gates.** `scripts/gate.sh` passes on the release commit, and
   `scripts/check-public.sh` (gitleaks over the full history).
4. **Rehearsal.** `XO_CLI=... scripts/check-release.sh v0.1.0 DIR`: tags
   a scratch clone and pushes the tags to a scratch bare remote, type
   checks every module with no workspace from those tags (after `xo mod
   tidy`, which must leave each xo.mod unchanged), and checks an app that
   gets the root and storage/v1 with `xo get`. No module carries an
   xo.lock: a program records its own.
5. **Publish (owner).** Merge the release branch into main and push it
   (`scripts/check-public.sh` first), then
   `scripts/first-release.sh v0.1.0 --push` from a clean main at that
   commit: annotated tags, the root first, 50 to a push.
6. **After.** A GitHub release for `v0.1.0` with
   [docs/releases/v0.1.0.md](releases/v0.1.0.md); the website's SDKs
   page switches to `xo get ...@v0.1.0` (its prepared commit).
