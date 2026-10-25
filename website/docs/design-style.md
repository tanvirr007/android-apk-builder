# Design style

The standing design contract for this site. The machine-readable subset lives in `docs/DESIGN.md`, and the design rules live here. When prompting an agent to modify the site, reference this file alongside `docs/impeccable.md` for visual standards and `docs/unslop.md` for editorial guidelines.

## Target audience

The site serves Windows developers who need to understand what the tool does, how to run it, which flags are available, and how to resolve build failures. Every element must serve a functional documentation purpose.

## Typography

- Use Source Sans 3 for human-readable text. Reserve JetBrains Mono for code blocks, inline commands, file paths, and parameter names.
- Host fonts locally through `@fontsource` using latin subsets, including weights 400, 600, and 700 for sans, and weight 400 for mono. Specify `font-display: swap`.
- Body text uses a 16px minimum floor with a line-height of 1.55 for paragraphs.
- Prose in standard reading columns is capped at 44rem, while in wide layouts paragraphs, lists, and lead text match the responsive container width to align flush with grids and code blocks. Headings use `text-wrap: balance`.

## Color

- Light theme is the default. The palette pairs a green accent family with neutral greys. The accent color is used only for link text, active navigation icons, and primary button backgrounds.
- Dark theme retains the same palette structure with a brighter accent. Avoid glow effects, neon borders, or radial halos. To emphasize a dark component, adjust surface or border colors rather than adding box shadows.
- The error color is reserved strictly for error messages and is never used decoratively.

## Layout

- Design mobile-first using fluid `clamp()` sizing and layout widths set via CSS custom properties. Main prose columns use a responsive measure (40rem to 50rem), while wide layouts scale across breakpoints from 56rem on mobile/tablet to 72rem (1152px) on laptops, 80rem (1280px) on desktop monitors, and 88rem (1408px) on ultrawide monitors. Side-by-side commands, 2-column feature grids, 3-column hardware profiles, and split troubleshooting accordions optimize horizontal space without creating unreadable line lengths.
- The spacing scale comprises 4px, 8px, 12px, 16px, 24px, 32px, 48px, 64px, and 96px. Gutter padding adapts fluidly between 16px on mobile up to clamp(48px, 4vw, 64px) on ultrawide monitors. Related elements sit close together, and major section gaps expand at 48px and 64px.
- Corner radii are restricted to 0px, 2px, 6px, and 10px. The floating navigation bar is the only pill-shaped element on the site.
- Avoid cards by default. Structured lists, tables, and section headings organize information. Where inset surfaces are required for code blocks, use solid backgrounds without combining borders and shadows.

## Navigation

- The navigation bar is a bottom-centered floating pill displaying icons with a 40px minimum touch target. Tooltips use `aria-label` and `title` attributes. On screens narrower than 360px, the bar scrolls horizontally without causing page-level overflow.
- Icons do not include subtitles. The active page displays a solid accent icon and an `aria-current` attribute.
- Navigation supports full keyboard access, displays an accent focus ring, and provides a skip-to-content link as the first DOM element.

## Theme

- The light theme is active by default. The toggle button opens a sheet providing light, dark, and system options. The selected mode persists in local storage under the `theme` key.
- `public/theme-core.js` runs synchronously in the HTML head without inline scripts and applies `data-theme` before first paint, preventing layout shifts or theme flashing.

## Copy rules

- Adhere to the editorial rules in `docs/unslop.md`. Use sentence case for all headings and write in US English. Avoid em dashes, prose parentheses, and marketing superlatives. Commands must match the repository README verbatim so copy-paste operations succeed reliably.
- Buttons use concise imperative verbs such as Copy, Copied, or Open. Avoid repetitive labels and decorative microcopy.

## Motion

- Default transitions use 160ms ease for color, border, and opacity changes. Modal sheets use a 220ms slide transition without bounce or overshoot. The `prefers-reduced-motion` media query disables transitions and animations entirely.
- Avoid marquees, pulse effects, blinking cursors, and entrance animations that could obscure content if scripts fail to load.

## Performance budget

- Total JavaScript across the site remains under 6 KB gzipped, consisting only of the theme script and the site utility script. The site uses zero framework runtime code.
- Each page loads a single external stylesheet and includes only the required latin font subsets. Target a mobile Lighthouse score of 95 or higher across all pages.
