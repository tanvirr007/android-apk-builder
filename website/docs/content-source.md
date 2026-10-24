# Content Source Map

Every page's copy traces to a README section so the site can never drift from
the tool's real behavior. When the README changes, update the page, then note
the sync here and in `progress.md`.

| Page | Source (repo root README.md) | Notes |
|---|---|---|
| Home `/` | "Overview" (lines 10-26), "The Self-Adapting Architecture" | Condensed to prose + short list. No marketing claims added |
| Quick Start `/quick-start` | "1. Quick Start" → wizard walkthrough + "Basic Invocations" | Steps mirror build.bat behavior exactly |
| How to Use `/how-to-use` | "1-Click Interactive Build Wizard", "Basic Invocations", section 2 "Conceptual Foundation", section 3 stage descriptions, memory section 5, section 4 key improvements | The long-form operation manual |
| CLI Reference `/cli-reference` | "Complete Parameter Reference" table (lines 119-146) | 24 parameters. Sheet details + example commands must quote README semantics |
| Troubleshooting `/troubleshooting` | Section 7 "Troubleshooting and Diagnostic Dictionary" (issues 1-8) | Copy is close to verbatim: these are real error strings |
| 404 `/404` | n/a | Own copy, references Home / How to Use / GitHub issues |
| Home compatibility matrix mention | Section 4.3 matrix table | Only referenced as a mention, not duplicated as a table (avoid stale duplication) |

## Copy policy

- Commands are copied character-for-character from README where they exist.
- Error strings in Troubleshooting are exact mono text (users paste-search them).
- Explanatory prose is rewritten in this site's voice (docs-utilitarian,
  zero marketing), but must not contradict README.
- Visitor counters and dynamic badges from README are excluded (static site,
  no third-party requests).

Sync log:
- 2026-10-25: initial mapping, all sections current as of this date.
