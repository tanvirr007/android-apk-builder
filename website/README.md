# Website `website/`

Documentation site for the [Android APK Builder](https://github.com/tanvirr007/android-apk-builder)
repository. Static Astro site, deployed on Vercel with the project **Root
Directory set to `website/`**.

## Quick reference

```cmd
cd website
npm install
npm run dev      rem http://localhost:4321
npm run build    rem output in website/dist
npx vercel       rem from this folder, first deploy
```

## Where things live

- `src/pages/` — the six pages. Content syncs against the repo README.
- `src/styles/global.css` — single stylesheet, theme tokens at the top.
- `DESIGN.md` — machine-readable design contract, kept in `docs/` with the
  other design docs. Every color/size/radius/font in the CSS must be listed
  there. Note: in docs/ placement the Impeccable token-drift gate is off by
  tool convention; the file is the authoritative subset either way.
- `docs/` — internal: `design-style.md` (style rules), `impeccable.md`
  (banned-pattern rules + QA gates), `content-source.md` (README → page map),
  `deploy.md` (Vercel steps), `progress.md` (worklog). This folder is
  excluded from deployments via `.vercelignore`.
- `public/theme-core.js` — tiny synchronous script applying the saved theme
  before first paint (no flash, CSP-clean).

## Conventions

- No em-dashes in copy. Commands are verbatim from the repo README.
- No gradients, no glassmorphism, no glow, no cards-with-stripe; see
  `docs/impeccable.md` before adding any visual component.
- All bundling is Astro-default; the only custom script is one site-wide
  module (copy buttons, dialog sheets, accordion exclusivity, picker).
