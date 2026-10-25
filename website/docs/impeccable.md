# Anti-slop rules

Catalog of design patterns excluded from this site based on the standards at https://impeccable.style/slop/.

## Construction rules

| Pattern | Exclusion rule |
|---|---|
| Purple gradients, blue-purple buttons or text | Palette uses a green accent and neutral greys defined in DESIGN.md. No gradients exist in the stylesheet. |
| Cream or beige editorial palette | Backgrounds are #F7F9F8 and #0F1512 without warm neutrals. |
| Glassmorphism, blurred panels, glow borders | No `backdrop-filter` or box-shadow glow styles. Surfaces use flat background colors or hairlines. |
| Gradient text | `background-clip: text` is excluded from all selectors. |
| Radial halo and soft spotlight backgrounds | No radial gradient background layers. |
| Repeating gradient stripes and decorative grid lines | No repeating gradients. Grids are structural layout only. |
| Oversized italic serif display headlines | Headings use sans-serif type in restrained sizes per DESIGN.md. |
| Generic default fonts | Source Sans 3 and JetBrains Mono are enforced across all elements. |
| Arbitrary corner radii | Radii are restricted to 0px, 2px, 6px, and 10px. |
| Side-tab accent stripes on cards | No striped card variants exist. |
| Hairline borders paired with wide shadows | Code blocks and buttons use flat backgrounds without paired shadows. |
| Neon glow in dark mode | Dark accent is flat #63C08A without box shadows or border glow. |

## Composition rules

| Pattern | Exclusion rule |
|---|---|
| Badge above headline | No decorative pill elements. Every visible element serves a functional purpose. |
| Eyebrow labels above headings | Headings stand alone without uppercase eyebrow labels. |
| Icon tiles stacked above headings | Feature cards with stacked icon tiles are excluded. |
| Identical card grids | Content uses varied layouts including prose, numbered lists, definition lists, tables, and accordions. |
| Hero metric displays | No metric counter callouts. |
| Massive icon tiles | Icons render at 20px in navigation and 22px inline. |
| Oversized hero headlines | Headings remain at or below 31px in sentence case under 60 characters. |
| Flat type hierarchy | Size steps between 16px, 26px, and 31px distinguish headings clearly. |
| Tiny interface text | 14px floor applies to captions and code blocks; buttons and navigation use 16px. |
| Uppercase body text | Use sentence case. Uppercase text is limited to short button labels. |
| Crushed letter spacing | Negative letter spacing below 19px is disallowed. |
| Excessive line length | Prose columns are capped at 44rem, approximately 66 characters per line. |
| Justified text | All body copy aligns to the start of the line. |
| Cramped padding | Interactive surfaces maintain a minimum of 16px padding. |
| Nested cards | Cards inside cards are prohibited. |
| Modal abuse | Each modal sheet displays one item. Settings panels in overlays are disallowed. |
| Entrance animation delays | Server-rendered content is visible immediately without requiring JavaScript execution. |
| Decorative cursors, pulsing dots, or marquees | None allowed. |
| Bounce or elastic easing | Transitions use standard easing curves without overshoot. |

## Copy rules

| Pattern | Exclusion rule |
|---|---|
| Em dash overuse | Avoid em dashes in site copy. Use periods and commas to separate clauses. |
| Generic marketing claims | Write descriptive, verifiable statements. Avoid promotional buzzwords. |
| Forced contrast slogans | Disallowed. |
| Calling features theater | Disallowed. |
| Repeated text in a single container | Label each interactive element once. |
| Redundant interface labels | Copy buttons display Copy until clicked, then show Copied. |
| Broken or placeholder assets | All images and social preview assets ship directly with the site build. |

## Quality assurance gates

1. Run `npx impeccable detect src/` against the source tree to verify compliance.
2. If scanning a deployment preview, verify that pages load without console errors, layout overflow, or clipped overlays.
3. Perform a manual review across light and dark themes to verify skip link functionality, navigation tooltips, single-item dialogs, and responsive behavior across widths from 320px to 1920px.
