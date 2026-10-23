# Pathwise - working notes

WoW Classic Era addon. Design: docs/PATHWISE_DESIGN.md, themes: docs/PATHWISE_THEMES.md + docs/PATHWISE_THEMES_V2.md (painted corner art) + docs/PATHWISE_THEMES_V3.md (emblem themes, 13 in all).

After every change:
1. Run the offline tests: `lua5.1 tests/run.lua` (all must pass).
2. Bump `## Version:` in both `Pathwise_Vanilla.toc` and `Pathwise.toc`
   (they must stay identical): patch for fixes, minor for features.
3. Commit and push to `origin main`.
4. Add a section for the new version to CHANGELOG.md (it becomes the
   release notes) before committing.
5. Build the zip: `tools/build_zip.sh ../Pathwise-<version>.zip` and send
   it to the user.
6. The zip goes on GitHub as a release through
   .github/workflows/release.yml. This session type can't create
   releases or push tags (both refused with 403), so the user starts it:
   Actions tab > Release > Run workflow. Remind them each time, with the
   link https://github.com/lagnelius-debug/Pathwise/actions/workflows/release.yml
   (tools/release.sh does the tag-push route for sessions that may push tags.)
