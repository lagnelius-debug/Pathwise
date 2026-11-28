---
name: pathwise-release
description: Release a change to the Pathwise WoW addon the way CLAUDE.md asks, end to end. The steps are the offline tests and real-data simulations, a version bump in all four TOCs, a CHANGELOG section, a commit and push to main, a check of the GitHub release and the CurseForge upload, and the zip sent to the user. Also merges an approved nightly-agent pull request ("godkänn #12", "approve #12", "merge the agent's PR"). Use it whenever a Pathwise change is finished and ready to ship, and when the user says "släpp", "release", "ship it", "push it", "ge mig zippen" or approves a pull request. Every change to main is a release here, so reach for this skill even when nobody says the word. Not for the nightly agent's own branch work: there the version isn't bumped.
---

# Releasing Pathwise

On this repo every push to `main` is a release.
`.github/workflows/release.yml` sees a TOC version that has no GitHub release yet. It then runs the tests again and publishes the release `v<version>` with the zip attached, using the notes from `CHANGELOG.md`. It also uploads the zip to CurseForge, where players get it.

So two things are true at once:

- A push without a version bump publishes nothing.
- A push with a bump reaches users within minutes.

Each step below is there to keep a broken or unexplained build from reaching them.

Don't use `tools/release.sh`. It pushes a tag, and this session type is refused (403) when it pushes tags or creates releases. That is why the workflow does both.

## 0. Know what you are releasing

```sh
git fetch -q origin main && git status --short && git log --oneline origin/main..HEAD && git log --oneline HEAD..origin/main
```

If `origin/main` has commits you don't have, rebase onto it first. The nightly agent never pushes to main, but the user might.

### When the user approves an agent pull request ("godkänn #N")

1. Find the branch: `gh api repos/lagnelius-debug/Pathwise/pulls/N --jq '.head.ref'`. It is normally `agent/issue-<issue>`.
2. Bring it in as is:
   ```sh
   git fetch origin <branch> && git merge --ff-only origin/<branch>
   ```
   - A fast-forward keeps the PR's commits, so GitHub marks the PR *merged* when main gets them. Its "Fixes #<issue>" then closes the issue.
   - If the fast-forward fails because main moved on, rebase the branch onto main locally, then use `git merge --ff-only`. The PR will show as closed, not merged. Mention that to the user.
3. Read the diff before you ship it: `git diff HEAD@{1}..HEAD --stat`, then the diff itself. The user approved the idea, and you are still the last check before players get it.

Never merge through the API, and never comment on, label or close anything. The user's approval covers this one PR only.

## 1. Tests and simulations

```sh
lua5.1 tests/run.lua 2>&1 | tail -3
tests/sim/run.sh 2>&1 | tail -5
```

Both must pass.

- `tests/run.lua` also runs the Forever suite in its own process.
- `tests/sim/run.sh` runs about 140 real-data scenarios plus `tests/sim/regressions.lua`. Each has a time budget: `SIM_BUDGET_MS` is 40 here and 100 in CI. On the first run it fetches QuestieDB into `tests/sim/.cache`.
- If one scenario fails only on time, run it again once. A slow container can go over budget. A scenario that fails twice is a real failure.

If a reported bug can be shown in the simulations and has no case in `tests/sim/regressions.lua` yet, add one now. That's a rule of the repo.

## 2. Pick the version and bump it

- **Patch** (0.58.3 → 0.58.4) is for fixes, data corrections and dev-only changes.
- **Minor** (0.58.3 → 0.59.0) is for features, including new dungeon data.

```sh
.claude/skills/pathwise-release/scripts/bump_version.sh 0.58.4
```

The script checks that the four TOCs agree. They are `Pathwise.toc`, `Pathwise_Vanilla.toc`, `Pathwise_Forever.toc` and `Pathwise_Camelot.toc`. Then it bumps all four. They must differ only in `## Interface:`, and `tests/run.lua` checks that.

If the change added a file to one TOC, it must be in all four.

## 3. CHANGELOG section

Add `## <version>` at the top, above the previous section. The workflow takes everything from that heading to the next `## ` as the release notes, on GitHub and on CurseForge. So write for players, in English:

- what changed in the game, and where to see it;
- for a fix, what was wrong before;
- for agent work, end with "(Prepared by the nightly agent, issue #N.)";
- for dev-only changes (tests, tools, CLAUDE.md, skills), say so: "No change in the game: …".

Keep to the style of the sections already there: plain bullet paragraphs wrapped at about 75 columns, no headings inside.

## 4. Commit and push

Stage the files by name, not with `git add -A`: the sim cache and other stray files must stay out. Then commit with a message like this:

```
Release <version>: <what changed, short>

<A line or two on why, if it isn't obvious.>

<the attribution lines from this session's system reminder>
```

The attribution lines (`Co-Authored-By: …` and `Claude-Session: …`) change from session to session. Copy them from the current reminder; don't copy them from an old commit.

```sh
git push origin main
```

If the network fails, retry up to 4 times with backoff. Don't force-push main.

## 5. Check that it went out

```sh
.claude/skills/pathwise-release/scripts/check_release.sh
```

The script:

- waits for the Release run of `HEAD`, up to about 15 minutes;
- prints the run's result and the newest release tag;
- prints the CurseForge step's annotation: `notice` means uploaded, `warning` means skipped, `error` means failed;
- exits non-zero when something is off.

Run it in the background so it doesn't hit the tool timeout. When it finishes:

- **Run failed:** look at the failed step. A test failure in CI means the release didn't happen. Fix it, bump again, and push again. A version with no release can be reused. Check with `gh api repos/lagnelius-debug/Pathwise/releases --jq '.[].tag_name'`.
- **Release but no CurseForge upload:** tell the user what the annotation says. Don't try to upload to CurseForge yourself. The token lives only in the `CURSEFORGE_API_TOKEN` secret.
- **Agent PR:** confirm that the PR shows as merged and the issue as closed:
  ```sh
  gh api repos/lagnelius-debug/Pathwise/pulls/N --jq .merged
  gh api repos/lagnelius-debug/Pathwise/issues/<issue> --jq .state
  ```

## 6. Build and send the zip

```sh
tools/build_zip.sh ../Pathwise-<version>.zip
```

The zip is built from the committed HEAD, so build it after the commit. Send it with `SendUserFile`, using the absolute path (for example `/home/user/Pathwise-0.58.4.zip`) and a short caption in the user's language. They install it straight into Interface/AddOns to test in game.

## 7. Report

Write a few lines in the user's language (Swedish so far):

- the version;
- what changed;
- tests and sims passed, with the counts;
- the release link `https://github.com/lagnelius-debug/Pathwise/releases/tag/v<version>`;
- whether CurseForge got it.

If any step was skipped or went wrong, say so plainly.
