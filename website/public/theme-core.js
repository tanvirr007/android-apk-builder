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
    if (resolve(m) === 'dark') root.setAttribute('data-theme', 'dark');
    else root.removeAttribute('data-theme');
    root.setAttribute('data-theme-mode', mode);
  }

  apply(mode);

  // "Follow system" keeps tracking OS changes.
  try {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function () {
      if (mode === 'system') apply('system');
    });
  } catch (e) { /* very old browsers: no listener, no harm */ }

  // Runtime hook for the site script.
  window.__setTheme = apply;
})();
