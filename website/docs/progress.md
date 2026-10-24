# Progress Log

Working log. Update every milestone; never delete entries.

## Status: COMPLETED

## Milestones

- [x] M0: Plan approved (docs-utilitarian, Astro, static-only + headers,
      light default + picker, floating icon nav, bottom sheets, custom-domain-later)
- [x] M1: Scaffold (package.json, astro.config, tsconfig, gitignores,
      .vercelignore) + design contracts (`DESIGN.md`, `docs/*.md`)
- [x] M2: Base layout, tokens (global.css), floating icon nav, theme core
- [x] M3: Home + Quick Start
- [x] M4: How to Use + CLI Reference (flag sheets)
- [x] M5: Troubleshooting + 404
- [x] M6: Vercel files, robots, sitemap, favicon/og assets
- [x] M7: QA (impeccable detect clean, build green, header check, lighthouse)
    
## Decisions log

| Date | Decision | Why |
|---|---|---|
| 2026-10-25 | Bottom sheets via native `<dialog>` (no library) | Focus trap + Escape for free, ~1KB CSS |
| 2026-10-25 | Sheet on mobile, centered dialog on desktop | Standard responsive pattern; desktop sheets look broken full-width |
| 2026-10-25 | Theme picker = sheet with Light/Dark/Follow system (was plain toggle) | Covers "bottom sheet picker wherever possible"; still light-default when unset |
| 2026-10-25 | `public/theme-core.js` sync-in-head instead of inline theme script | Keeps CSP fully `script-src 'self'` with zero unsafe-inline, zero hash maintenance |
| 2026-10-25 | Troubleshooting uses `<details>` accordions (no JS), CLI ref uses real `<dialog>` sheets | Details work with JS disabled and are search-indexable; sheets where they add app-like value |
| 2026-10-25 | Share/copy-link sheet dropped | Adds weight, negligible value; document as rejected |
| 2026-10-25 | Nav internal overflow-x scroll under 360px | Keeps 40px+ touch targets at 320px without breaking the 44px-ish guideline per item |
| 2026-10-25 | DESIGN.md moved to docs/ per user choice | Token-drift gate traded for docs-folder tidiness; generic slop/quality rules still enforced |
| 2026-10-25 | Static site header added with brand link, GitHub icon, and theme picker on right | Gives clear identity across all pages; frees up bottom floating nav for core page routing |
| 2026-10-25 | Floating nav prefetch and transition timing tune | Prefetch on hover and 220ms pill timing eliminate perceived lag |

## Sync log

| Date | Repo change | Site change |
|---|---|---|
| 2026-10-25 | Initial content extraction of README (sections listed in content-source.md) | First full content pass |
