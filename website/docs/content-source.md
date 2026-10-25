# Content source map

Every page copy traces to a README section so the site reflects the engine behavior. When the repository README changes, update the corresponding page and log the sync here and in `progress.md`.

| Page | README source | Notes |
|---|---|---|
| Home `/` | Overview and self-adapting architecture | Condensed to prose and a summary list without marketing claims |
| How to use `/how-to-use` | Interactive build wizard, basic invocations, architecture stages, memory configuration, and key improvements | Long-form operator manual |
| Troubleshooting `/troubleshooting` | Troubleshooting and diagnostic dictionary, issues 1 through 8 | Error strings match terminal output exactly |
| 404 `/404` | Not applicable | Custom page linking to Home, How to use, and GitHub issues |

## Copy policy

- Commands match the repository README verbatim.
- Error strings in Troubleshooting use exact monospace text so users can search them.
- Explanatory prose uses direct, technical language conforming to `docs/unslop.md` without marketing claims.
- Dynamic visitor counters and badges are excluded to keep the site fully static.

## Sync log

- 2026-10-25: Initial mapping verified against repository README.
