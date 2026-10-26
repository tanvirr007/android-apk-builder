// Applied synchronously in <head>, before first paint. No flash, no inline script.
// Storage: localStorage["theme"] = "light" | "dark" | "system". Absent value is light.
(function () {
  var KEY = 'theme';
  var mode = 'light';
  try { mode = localStorage.getItem(KEY) || 'light'; } catch (e) { /* storage unavailable */ }
  if (mode !== 'dark' && mode !== 'light' && mode !== 'system') mode = 'light';

  var root = document.documentElement;

  function resolve(m) {
    if (m !== 'system') return m;
    try {
      return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    } catch (e) { return 'light'; }
  }

  function apply(m) {
    mode = m;
    var el = document.documentElement;
    if (resolve(m) === 'dark') el.setAttribute('data-theme', 'dark');
    else el.removeAttribute('data-theme');
    el.setAttribute('data-theme-mode', mode);
  }

  apply(mode);

  // "Follow system" keeps tracking OS changes.
  try {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function () {
      if (mode === 'system') apply('system');
    });
  } catch (e) { /* very old browsers: no listener, no harm */ }

  // Pre-apply theme to incoming document before swap to prevent any flash of light mode
  document.addEventListener('astro:before-swap', function (event) {
    if (event.newDocument && event.newDocument.documentElement) {
      if (resolve(mode) === 'dark') {
        event.newDocument.documentElement.setAttribute('data-theme', 'dark');
      } else {
        event.newDocument.documentElement.removeAttribute('data-theme');
      }
      event.newDocument.documentElement.setAttribute('data-theme-mode', mode);
    }
  });

  // Re-apply theme on current document after swap to ensure active references match
  document.addEventListener('astro:after-swap', function () {
    apply(mode);
  });

  // Runtime hook for the site script.
  window.__setTheme = apply;
})();
