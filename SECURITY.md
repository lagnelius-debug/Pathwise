# Security Policy

Pathwise is a World of Warcraft addon maintained by one person as a hobby project. Thank you for helping keep it and its users safe.

## Supported versions

Only the **latest release** receives security fixes. If you are on an older version, update through your addon manager (CurseForge, Wago or WowUp) before reporting.

| Version | Supported |
|---|---|
| Latest release | ✅ |
| Older releases | ❌ |

| Game version | Supported |
|---|---|
| WoW Classic Era | ✅ |
| World of Warcraft: Forever | ✅ (once supported releases are published) |

## Official download sources

Pathwise is only published at:

- CurseForge — the official Pathwise project page
- Wago Addons — the official Pathwise project page (if listed)
- GitHub Releases in this repository

Copies from any other site, Discord upload or "addon pack" are **not** official and may be modified. If you find a modified or fake copy of Pathwise being distributed, please report it (see below).

## What counts as a security issue

Addons run inside WoW's own sandbox, so the risks are limited, but please report anything like:

- Code in Pathwise that sends chat or addon messages, or performs actions, without the player intending it
- A way for **another player** to make Pathwise do something (for example through addon messages, chat links or shared data) — crashes, freezes, spam, or reading or changing the player's settings
- Pathwise storing anything sensitive in its SavedVariables that it shouldn't
- Problems in this repository's release process — for example the GitHub Actions workflow, leaked tokens or API keys, or a release package containing files that aren't in the source
- Fake or tampered copies of Pathwise, as above

**Not** security issues (please open a normal issue instead): Lua errors, wrong recommendations, visual bugs, performance problems, or conflicts with other addons.

## How to report

**Please do not open a public issue for security problems.**

Use GitHub's private reporting: go to this repository's **Security** tab and click **Report a vulnerability**. Only you and the maintainer can see the report.

Please include:

- The Pathwise version and game version (Classic Era or Forever)
- What happens, and the steps to reproduce it
- Any Lua error text (BugSack output is ideal), screenshots or example data
- Whether another player is needed to trigger it

## What to expect

- **Acknowledgement** within **7 days**
- An initial assessment, and a rough plan if it's confirmed, within **14 days**
- A fixed release as soon as reasonably possible, depending on severity
- Credit in the release notes if you'd like it — tell me the name to use

This is a one-person project, so response times are best effort. Please give me a reasonable chance to release a fix before sharing details publicly.

## Safe harbor

Good-faith research is welcome. Please only test with your own characters and accounts, don't disrupt other players or Blizzard's services, and follow Blizzard's Terms of Use while doing so.
