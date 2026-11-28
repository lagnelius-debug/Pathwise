# Pathwise - working notes

WoW Classic Era addon, also for WoW Forever (1.60.1, interface 16001).
Every TOC loads Platform/Platform_Forever.lua after Platform_Classic.lua;
it does nothing outside Forever and there replaces only what differs on
Forever's modern API. Design: docs/PATHWISE_DESIGN.md, themes: docs/PATHWISE_THEMES.md + docs/PATHWISE_THEMES_V2.md (painted corner art) + docs/PATHWISE_THEMES_V3.md (emblem themes) + docs/PATHWISE_THEMES_V4.md (Azure, tiled frame; 14 in all).

After every change (the project skill `pathwise-release` in
.claude/skills/pathwise-release does all of these steps, with scripts for
the version bump and for checking the release; tools/release.sh is
outdated, as it pushes a tag):
1. Run the offline tests: `lua5.1 tests/run.lua` (all must pass; it also
   runs the Forever suite, tests/run_forever.lua, in its own process), and
   the real-data simulations: `tests/sim/run.sh` (it fetches QuestieDB at a
   pinned commit into tests/sim/.cache the first time; 140 zone, dungeon
   and language scenarios plus the reported cases in
   tests/sim/regressions.lua, each with a time budget per plan). The
   release workflow runs both before publishing. A reported bug that the
   simulations can show gets a case in tests/sim/regressions.lua.
2. Bump `## Version:` in all four TOCs - `Pathwise_Vanilla.toc` (11509),
   `Pathwise_Forever.toc` and `Pathwise_Camelot.toc` (16001) and the
   fallback `Pathwise.toc` (11509, 16001); they're identical but for the
   interface line (tests/run.lua checks), e.g.
   `sed -i 's/^## Version: OLD$/## Version: NEW/' Pathwise*.toc`: patch for
   fixes, minor for features. A file added to one TOC goes in all four.
3. Commit and push to `origin main`.
4. Add a section for the new version to CHANGELOG.md (it becomes the
   release notes) before committing.
5. Build the zip: `tools/build_zip.sh ../Pathwise-<version>.zip` and send
   it to the user.
6. The zip goes on GitHub by itself: .github/workflows/release.yml runs on
   every push to main and publishes a release (tag `v<version>`, zip
   attached, notes from CHANGELOG.md) when the TOC version has none yet.
   So every change must bump the version. After pushing, check the run
   and the release with the REST API, e.g.
   `gh api repos/lagnelius-debug/Pathwise/releases --jq '.[0].tag_name'`.
   (This session type can't create releases or push tags itself - both
   are refused with 403 - which is why the workflow does it.)
   The workflow also uploads a new release to CurseForge
   (tools/curseforge_upload.sh) once the CURSEFORGE_API_TOKEN secret is
   set (project ID: "## X-Curse-Project-ID:" in the TOCs); a skipped or
   failed upload shows in the run's "Upload to CurseForge" step.

## The nightly agent

A scheduled task (the daily GitHub check) also works on issues labelled
`agent`, one per night, in this order: the oldest labelled issue that has
no open pull request yet.
- Work on a branch `agent/issue-<number>` from the latest main; never push
  to main (a push to main publishes a release on GitHub and CurseForge).
  Don't bump the version or add a CHANGELOG section on the branch: that
  happens when the user merges (see "After every change"): on the user's
  approval ("godkänn #N"), the `pathwise-release` skill fast-forwards the
  branch into main and releases it.
- Keep to what the issue asks. Add tests; a bug the simulations can show
  gets a case in tests/sim/regressions.lua.
- `lua5.1 tests/run.lua` and `tests/sim/run.sh` must pass. If they can't be
  made to pass, or the issue is unclear or too big for one change, open no
  pull request: say so in the conversation instead.
- Open a pull request ("Fixes #<number>"), build a test zip, send it and a
  push notification, and stop. The Tests workflow runs on the pull request.
- Never merge, and never comment on, close or label issues or pull
  requests without the user's go-ahead.
