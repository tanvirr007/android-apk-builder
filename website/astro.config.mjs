// @ts-check
import { defineConfig } from 'astro/config';

// Canonical URL for the production site.
export default defineConfig({
  site: 'https://pkg.tanvir.info',
  output: 'static',
  compressHTML: true,
  prefetch: {
    prefetchAll: true,
    defaultStrategy: 'hover',
  },
  devToolbar: {
    enabled: false,
  },
  build: {
    inlineStylesheets: 'auto',
  },
});
