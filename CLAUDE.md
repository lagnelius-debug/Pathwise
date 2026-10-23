# Pathwise - working notes

WoW Classic Era addon. Design: docs/PATHWISE_DESIGN.md, themes: docs/PATHWISE_THEMES.md.

After every change:
1. Run the offline tests: `lua5.1 tests/run.lua` (all must pass).
2. Bump `## Version:` in both `Pathwise_Vanilla.toc` and `Pathwise.toc`
   (they must stay identical): patch for fixes, minor for features.
3. Commit and push to `origin main`.
4. Run `tools/release.sh "short release notes"`: it builds
   `../Pathwise-<version>.zip` locally and pushes the tag `v<version>`;
   the GitHub Actions workflow (.github/workflows/release.yml) then
   publishes the release with the zip attached. (This session type can't
   create releases through the API, hence the workflow.) The user always
   wants the new zip on GitHub - check the release appeared.
5. Send the zip to the user as well.
