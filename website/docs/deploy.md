# Deployment (Vercel)

## First deploy (recommended: GitHub import)

1. Push the repo to GitHub (site code is in `website/`).
2. vercel.com → Add New → Project → import `tanvirr007/android-apk-builder`.
3. In "Root Directory" settings choose `website` (Framework Preset: Astro
   auto-detects). Build Command: `astro build` (default). Output: `dist`.
4. Deploy. Later pushes to the default branch redeploy automatically; PRs get
   preview URLs that inherit all security headers.

## First deploy (CLI alternative)

```cmd
cd website
npx vercel@latest
```

The project link lands in `.vercel/` (git-ignored). Production deploy:
`npx vercel --prod`.

## Custom domain (planned, not yet connected)

1. Vercel dashboard → Domains → add the domain.
2. Update these three files to the new canonical origin and commit:
   - `astro.config.mjs` (`site` parameter)
   - `public/robots.txt` (Sitemap line)
   - `public/sitemap.xml` (all `<loc>` URLs)
3. HSTS is already sent by `vercel.json` with `includeSubDomains`, so the
   domain serves HTTPS-only traffic from day one.

## Header verification after any deploy

```cmd
curl -I https://<deploy-url>/
```

Expect on every response: strict `Content-Security-Policy` (`default-src
'none'`, `script-src 'self'`, no `unsafe-inline`), `X-Frame-Options: DENY`,
`X-Content-Type-Options: nosniff`, `Referrer-Policy`, `Permissions-Policy`
with camera/mic/geolocation denied, `Cross-Origin-Opener-Policy`,
`Cross-Origin-Resource-Policy`, and immutable cache on `/_astro/*`.

Fast fail-closed build: if a dependency or path changes and the CSP would
need loosening to work, fix the site to work under the strict policy. The
policy does not get loosened.

## Notes

- `docs/` is excluded from the deployment bundle via `.vercelignore`.
  Prompts, worklogs, and QA notes stay repo-only.
- Static-only: no serverless functions, no env vars, no secrets exist for
  this project. `form-action 'none'` and `connect-src` policy keep it that way.
- `trailingSlash: never` + `cleanUrls: true` produce one canonical URL per page.
