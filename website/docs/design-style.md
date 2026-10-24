# Website Design Style

The standing design contract for this site. The machine-readable subset lives in
`docs/DESIGN.md` (deliberately kept with the docs, so the Impeccable detector's
token-drift gate is off; generic slop and quality checks still run). The
reasoning and rules live here. Prompt-style usage: when asking any model or
agent to touch the site, paste or link this file plus `docs/impeccable.md`.

## Who this site is for

A Windows developer who cloned this repo and wants to know, in five minutes:
what is this tool, how do I run it, which flags exist, and what do I do when a
build fails. Docs-utilitarian. Nothing decorative earns its place.

## Type

- Source Sans 3 for everything human-readable; JetBrains Mono only for code,
  commands, file paths, and parameter names.
- Self-hosted via @fontsource, subsets: latin only, weights 400/600/700 sans,
  400 mono. `font-display: swap`.
- Body 16px minimum everywhere, line-height 1.55 for paragraphs.
- Prose measure 44rem (~66ch). Headings `text-wrap: balance`.

## Color

- Light is the default theme. One green accent family, one neutrals ramp.
  Accent appears as: link text, active nav icon fill, primary button background.
  That is the complete list of allowed uses.
- Dark theme: same structure, brighter accent, no glow, no neon border, no
  radial halo. If a dark component needs emphasis, it gets a surface color
  change or a border color change, never a shadow-glow.
- Error color exists strictly for error text; it is never decorative.

## Layout

- Mobile-first, fluid `clamp()` type, single max-widths via CSS custom
  properties. Main prose column max 44rem; wide pages (reference tables) 56rem.
- Spacing scale 4/8/12/16/24/32/48/64/96. Related items sit closer than
  unrelated ones; section gaps step up at 48/64. Deliberately not uniform 16px
  everywhere (anti "monotonous spacing").
- Radii: 0 / 2 / 6 / 10. Nothing pill-shaped except the floating nav itself,
  which is the only intentional pill on the site.
- Cards: none by default. Lists, tables, and headings do the work. Where an
  inset surface is needed (code blocks), background-only, no border + shadow
  pair.

## Navigation

- Floating pill, bottom-center, icons only, 40px min touch target, tooltip
  text via `aria-label` + `title`. Overflow-x scroll internally on screens
  under 360px; page itself never scrolls sideways.
- No subtitles under icons. Active page: solid accent icon + `aria-current`.
- Keyboard reachable, focus-visible ring in accent, skip-to-content link first
  in DOM.

## Theme

- Light default. Toggle opens the theme picker sheet (Light / Dark / Follow
  system). Choice persists in `localStorage["theme"]`.
- `public/theme-core.js` runs synchronously in `<head>` (plain file, strict
  CSP-friendly, no inline script needed) and sets `data-theme` before first
  paint: no flash, no hydration dependency.

## Copy rules

- Sentence case headings. US English. No em-dashes; periods and commas do the
  separating. No marketing superlatives. Commands are verbatim from the repo's
  README so copy-paste always works.
- Buttons say the verb: "Copy", "Copied", "Open in sheet". No decorative
  microcopy, no repeated labels inside one block.

## Motion

- Default: 160ms ease for color/border/opacity only. Sheets: 220ms slide with
  0ms settle, no bounce, no elastic. `prefers-reduced-motion` removes all
  transitions/animations.
- No marquee, no pulse, no blinking cursor, no entrance animations that hide
  content on failure (content is visible by default).

## Performance budget

- Total JS on any interaction-heavy page under ~6KB gzipped (theme core +
  one bundled site script). Zero framework runtime.
- Each page: one external stylesheet, font files limited to the exact
  latin subsets and weights used. Lighthouse mobile 95+ target on all pages.
