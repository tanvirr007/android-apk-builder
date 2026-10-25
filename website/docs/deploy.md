# Deployment on Vercel

## First deployment with GitHub import

1. Push the repository to GitHub. Site code resides in `website/`.
2. In the Vercel dashboard, select Add New, then Project, and import `tanvirr007/android-apk-builder`.
3. Set the Root Directory setting to `website`. Vercel auto-detects the Astro preset, uses `astro build` as the default build command, and directs output to `dist`.
4. Deploy the project. Subsequent pushes to the default branch deploy automatically. Pull requests receive preview URLs that inherit all security headers.

## First deployment with Vercel CLI

```cmd
cd website
npx vercel@latest
```

The project configuration links in `.vercel/`, which is ignored by git. Run `npx vercel --prod` for production deployment.

## Custom domain setup

1. In the Vercel dashboard, navigate to Domains and add the domain.
2. Update three files to the new canonical origin and commit the changes:
   - `astro.config.mjs`, updating the `site` parameter
   - `public/robots.txt`, updating the Sitemap URL
   - `public/sitemap.xml`, updating all `<loc>` URLs
3. The `vercel.json` configuration includes HSTS with subdomains enabled, ensuring HTTPS enforcement from initial deployment.

## Header verification after deployment

```cmd
curl -I https://<deploy-url>/
```

Verify that responses include strict security headers. Expected headers include `Content-Security-Policy` with default set to none and scripts restricted to self without unsafe inline, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `Permissions-Policy` denying camera, microphone, and geolocation, `Cross-Origin-Opener-Policy`, `Cross-Origin-Resource-Policy`, and immutable cache headers on `/_astro/*`.

If a dependency or asset requires Content Security Policy changes, adjust the site assets to comply with the existing strict policy rather than loosening security directives.

## Deployment notes

- `.vercelignore` excludes `docs/` from the deployment bundle so internal documentation remains repository-only.
- The site is fully static with no serverless functions, environment variables, or secrets. Strict `form-action` and `connect-src` directives enforce this boundary.
- Configuration flags `trailingSlash: never` and `cleanUrls: true` generate a single canonical URL for each page.
