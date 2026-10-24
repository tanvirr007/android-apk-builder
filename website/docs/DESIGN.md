# Design System

Machine-readable design contract for the site, kept in `docs/` with the other
design documents. The Impeccable detector loads context files named
`DESIGN.md` from a project root, so token-drift checks against this file are
currently disabled (the team chose docs-folder tidiness over that gate).
Generic slop and quality rules still run. Every font, color, type size, and
corner radius used in `src/styles/global.css` must stay within this list.

## Fonts

- "Source Sans 3" — UI and body text
- "JetBrains Mono" — code blocks, inline code, commands
- Fallback stack (non-visual identity, accepted): system-ui, Segoe UI, Roboto, Helvetica, Arial

## Font sizes

- 14px — captions, code blocks, table cell details
- 16px — body text (never smaller for paragraphs or interface controls)
- 19px — minor headings, lead paragraph, small section titles
- 22px — h3
- 26px — h2
- 31px — h1

## Colors

### Light (default)

- #F7F9F8 — page background
- #FFFFFF — surface
- #EFF3F1 — code block and inset background
- #16211B — primary text
- #4C5F55 — secondary text, captions
- #D9E1DD — hairline borders, dividers
- #1B6E43 — accent: links, active nav icon, button background
- #F7F9F8 — text on accent background
- #24352C — code text on inset
- #B4463A — error text only (never decoration)

### Dark

- #0F1512 — page background
- #161E19 — surface
- #1B251F — code block and inset background
- #E2EAE4 — primary text
- #9FAFA5 — secondary text, captions
- #26332B — hairline borders, dividers
- #63C08A — accent: links, active nav icon
- #2FA05F — button background
- #0F1512 — text on accent background
- #E0857A — error text only (never decoration)

## Corner radius

- 0px — default element
- 2px — inline code, chips
- 6px — buttons, inputs, command blocks
- 10px — code block surfaces, bottom sheets
