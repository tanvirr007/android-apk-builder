# Documentation site

Documentation site for the [Android APK Builder](https://github.com/tanvirr007/android-apk-builder) repository. Built with Astro as a static site and deployed on Vercel with the project root directory set to `website/`.

## Quick reference

```cmd
cd website
npm install
npm run dev      rem http://localhost:4321
npm run build    rem output in website/dist
npx vercel       rem deploy from this directory
```

## Directory structure

- `src/pages/`: Contains the site pages, synchronized with the repository README.
- `src/styles/global.css`: Single stylesheet with design tokens defined at the top.
- `docs/DESIGN.md`: Design contract listing allowed colors, type sizes, corner radii, and font families.
- `docs/`: Internal reference files, including `design-style.md`, `impeccable.md`, `unslop.md`, `content-source.md`, `deploy.md`, and `progress.md`. Excluded from production deployments by `.vercelignore`.
- `public/theme-core.js`: Synchronous script that sets the saved theme before first paint without inline scripts.

## Conventions

- Follow the copy rules in `docs/unslop.md` when writing or editing documentation. Avoid em dashes, parentheses in prose, and marketing superlatives. Commands match the repository README verbatim.
- Avoid gradients, glassmorphism, glow effects, or decorative card stripes. Review `docs/impeccable.md` before adding visual components.
- Rely on default Astro bundling. The only custom script is `public/site.js`, which manages copy buttons, dialog sheets, and accordion state.
