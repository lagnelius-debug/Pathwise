# Pathwise - working notes

WoW Classic Era addon. Design: docs/PATHWISE_DESIGN.md, themes: docs/PATHWISE_THEMES.md.

After every change:
1. Run the offline tests: `lua5.1 tests/run.lua` (all must pass).
2. Bump `## Version:` in both `Pathwise_Vanilla.toc` and `Pathwise.toc`
   (they must stay identical): patch for fixes, minor for features.
3. Commit and push to `origin main`.
4. Run `tools/release.sh "short release notes"`: it builds
   `../Pathwise-<version>.zip` and publishes it as a GitHub release
   (tag `v<version>`) with the zip attached. The user always wants the
   new zip on GitHub.
5. Send the zip to the user as well.
