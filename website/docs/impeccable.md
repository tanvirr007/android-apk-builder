# Anti-Slop Rules (from impeccable.style/slop)

The catalog at https://impeccable.style/slop/ documents 68 current-generation
AI-design habits. This file translates every relevant one into a concrete rule
for THIS site, so any agent that reads it cannot accidentally ship slop.
QA gate: `npx impeccable detect src/` must pass clean before each milestone is
marked done in `docs/progress.md`.

## Banned on sight (construction-level)

| Slop pattern | Why it is structurally excluded here |
|---|---|
| Purple gradients, blue-purple buttons/text | Palette is a green + neutrals ramp fixed in DESIGN.md. No gradients exist in the CSS at all |
| Cream / beige editorial palette | Backgrounds are #F7F9F8 and #0F1512. No warm neutrals |
| Glassmorphism, blur panels, glow borders | No `backdrop-filter`, no box-shadow glows. Cards use background or a 1px hairline, never both |
| Gradient text | `background-clip: text` does not appear anywhere |
| Radial halo / soft spotlight backgrounds | No radial-gradient background layers |
| Repeating-gradient stripes, decorative grid lines | No repeating gradients; grids are CSS layout only |
| Oversized italic serif display headline | Headlines are sans, restrained sizes per DESIGN.md scale |
| Overused default font (Inter, Geist) | Source Sans 3 + JetBrains Mono, confirmed against DESIGN.md by the detector |
| Banned-radius buffet (pill cards, 24px+ blobs) | Radius scale 0/2/6/10 only |
| Side-tab accent stripe on cards | No striped card variant exists |
| Hairline border paired with wide shadow | Code blocks: background only. Buttons: background only |
| Neon glow in dark mode | Dark accent is flat #63C08A, no box-shadow, no border-glow |

## Banned on sight (composition-level)

| Slop pattern | Our rule |
|---|---|
| Badge above headline | No decorative pills. Every visible element does a job |
| Label above a heading (tiny caps eyebrow line) | Forbidden. Headings stand alone |
| Icon tile stacked above heading | No icon-tile feature cards. The site has no feature grid at all |
| Identical card grids | Pages use five different shapes: prose, numbered steps, definition lists, a reference table, accordion details. No two sections share one grid template |
| Hero metric layout (giant number + label) | There is no metrics section |
| Massive icon tiles | Icons render at 20px in nav, 22px inline. Nothing larger |
| Oversized hero headline | h1 always ≤ 31px (DESIGN.md scale), sentence case, ≤ 60 characters |
| Flat type hierarchy | 16 → 26 → 31 jumps keep h2 and h1 visibly distinct |
| Tiny interface text | 14px floor only for captions/code; nav and buttons are 16px |
| All-caps body text | Sentence case; caps only for short button labels |
| Crushed letter spacing | No negative tracking below 19px |
| Line length too long | Prose capped at 44rem (~66ch) |
| Justified text | `text-align: start` everywhere |
| Cramped padding | Spacing scale enforced per component (16px minimum padding on interactive surfaces) |
| Nested cards | No card-inside-card anywhere |
| Modal abuse | Each `<dialog>`/sheet contains exactly one item's details. No settings walls inside overlays |
| Content stuck waiting to appear | No entrance animations; content is server-rendered and visible without JS |
| Decorative blinking cursor / pulsing dot / marquee | None |
| Bounce or elastic easing | `cubic-bezier(0.2, 0, 0, 1)`, no overshoot values |

## Banned on sight (copy-level)

| Slop pattern | Our rule |
|---|---|
| Em-dash overuse | Zero em-dashes in site copy. Periods and commas |
| Generic claims ("supercharge", "world-class", "seamless") | Descriptive, verbatim-capable statements only. Example of allowed tone: "Builds APKs without Android Studio" |
| Forced contrast slogans ("Not X. A platform.") | Forbidden |
| Calling things "theater" | Never used |
| Same text repeated in one container | Label each interactive element once |
| Redundant UX writing | Copy buttons say "Copy" and nothing else until the copied state flips to "Copied" |
| Placeholder/broken imagery | All images ship with the build; og.png is generated and verified before deploy |

## QA gates (run every milestone and before deploy)

1. `npx impeccable detect src/` against the source tree. Expect zero findings.
2. Built-site scan (if supported): `npx impeccable detect <preview-url>`.
   Checks the browser-level rules: no JS errors on load, no overflow, no
   clipped overlays, contrast on real backgrounds.
3. Manual pass on every page, both themes: skip link works, nav tooltips
   present, one `<dialog>` contains one item, no horizontal scroll at
   320/360/412/768/1024/1440/1920 widths, print preview sane.
