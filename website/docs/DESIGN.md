# Design system

Machine-readable design contract for the site, kept in `docs/` alongside the design documentation. Every font, color, type size, and corner radius used in `src/styles/global.css` must remain within this list.

## Fonts

- "Poppins": UI, headings, body text, and interface controls
- "JetBrains Mono": code blocks, inline code, and commands
- Fallback stack: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif

## Font weights

- 400 (Regular): body text, lead paragraph body, list items, and descriptions
- 500 (Medium): command captions, copy buttons, table captions
- 600 (SemiBold): h3 headings, interactive buttons, table headers, step headers, modal headers
- 700 (Bold): h1 headings, h2 headings, brand name, step badges

## Font sizes

- 14px: captions, code blocks, copy buttons, and table cell details
- 16px: body text, brand name, and interface controls
- 19px: minor headings, lead paragraphs, step titles, and modal headers
- 22px: h3 headings
- 26px: h2 headings
- 32px: h1 headings

## Colors

### Light theme

- #F7F9F8: page background
- #FFFFFF: surface
- #EFF3F1: code block and inset background
- #16211B: primary text
- #4C5F55: secondary text and captions
- #D9E1DD: hairline borders and dividers
- #1B6E43: accent color for links, active navigation icons, and button backgrounds
- #F7F9F8: text on accent background
- #24352C: code text on inset surfaces
- #B4463A: error text only

### Dark theme

- #0F1512: page background
- #161E19: surface
- #1B251F: code block and inset background
- #E2EAE4: primary text
- #9FAFA5: secondary text and captions
- #26332B: hairline borders and dividers
- #63C08A: accent color for links and active navigation icons
- #2FA05F: button background
- #0F1512: text on accent background
- #E0857A: error text only

## Corner radii

- 0px: default element
- 2px: inline code and chips
- 6px: buttons, inputs, and command blocks
- 10px: code block surfaces and bottom sheets
