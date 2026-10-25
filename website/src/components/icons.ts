/**
 * Inline SVG icon set. Stroke icons use currentColor (2px, round caps);
 * brand marks use fill. No runtime icon library, no external requests.
 */
export type IconName =
  | 'home' | 'book' | 'wrench'
  | 'sun' | 'moon' | 'github' | 'copy' | 'check' | 'chevron'
  | 'globe' | 'telegram';

const icons: Record<IconName, { viewBox: string; fill: boolean; body: string }> = {
  home: {
    viewBox: '0 0 24 24',
    fill: false,
    body: '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.7V21h5.2v-5.5h3.6V21H19V9.7"/>',
  },
  book: {
    viewBox: '0 0 24 24',
    fill: false,
    body: '<path d="M6 2.5h12.5v19H8.5a2.5 2.5 0 0 1-2.5-2.5V2.5z"/><path d="M6 16h12.5"/>',
  },
  wrench: {
    viewBox: '0 0 24 24',
    fill: false,
    body: '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>',
  },
  sun: {
    viewBox: '0 0 24 24',
    fill: false,
    body: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/>',
  },
  moon: {
    viewBox: '0 0 24 24',
    fill: false,
    body: '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>',
  },
  github: {
    viewBox: '0 0 16 16',
    fill: true,
    body: '<path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"/>',
  },
  globe: {
    viewBox: '0 0 24 24',
    fill: false,
    body: '<circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/>',
  },
  telegram: {
    viewBox: '0 0 24 24',
    fill: true,
    body: '<path d="M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm5.894 8.221-1.97 9.28c-.145.658-.537.818-1.084.508l-3-2.21-1.446 1.394c-.14.18-.357.295-.6.295-.002 0-.003 0-.005 0l.213-3.054 5.56-5.022c.24-.213-.054-.334-.373-.121l-6.869 4.326-2.96-.924c-.643-.204-.657-.643.136-.953l11.57-4.461c.537-.196 1.006.128.832.942z"/>',
  },
  copy: {
    viewBox: '0 0 24 24',
    fill: false,
    body: '<rect x="9" y="9" width="12" height="12" rx="2"/><path d="M5 15c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h9c1.1 0 2 .9 2 2"/>',
  },
  check: {
    viewBox: '0 0 24 24',
    fill: false,
    body: '<path d="m4 12.5 5 5L20 6.5"/>',
  },
  chevron: {
    viewBox: '0 0 24 24',
    fill: false,
    body: '<path d="m9 6 6 6-6 6"/>',
  },
};

/** Render an inline <svg>. */
export function icon(name: IconName, extraClass = ''): string {
  const spec = icons[name];
  const attrs = spec.fill
    ? 'fill="currentColor"'
    : 'fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"';
  return `<svg ${attrs} viewBox="${spec.viewBox}" width="24" height="24" aria-hidden="true"${extraClass ? ` class="${extraClass}"` : ''}>${spec.body}</svg>`;
}
