# Pathwise - working notes

WoW Classic Era addon, also for WoW Forever (1.60.1, interface 16001:
Pathwise_Forever.toc / Pathwise_Camelot.toc load Platform/Platform_Forever.lua
after Platform_Classic.lua; it replaces only what differs on Forever's
modern API). Design: docs/PATHWISE_DESIGN.md, themes: docs/PATHWISE_THEMES.md + docs/PATHWISE_THEMES_V2.md (painted corner art) + docs/PATHWISE_THEMES_V3.md (emblem themes) + docs/PATHWISE_THEMES_V4.md (Azure, tiled frame; 14 in all).

After every change:
1. Run the offline tests: `lua5.1 tests/run.lua` (all must pass; it also
   runs the Forever suite, tests/run_forever.lua, in its own process).
2. Bump `## Version:` in all four TOCs - `Pathwise_Vanilla.toc`,
   `Pathwise.toc` (identical to it), `Pathwise_Forever.toc` and
   `Pathwise_Camelot.toc` (identical to it), e.g.
   `sed -i 's/^## Version: OLD$/## Version: NEW/' Pathwise*.toc`: patch for
   fixes, minor for features. A file added to the Vanilla TOC goes in the
   Forever ones too (tests/run.lua checks).
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
