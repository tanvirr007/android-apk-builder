/* Site interactions, event-delegated with Astro ClientRouter support.
   1. copy buttons  2. theme toggle  3. desktop nav active state
   4. floating dock indicator  5. accordion exclusivity (details)
   6. directional view transitions */
(function () {
  'use strict';

  /* ---------- copy buttons ---------- */
  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext !== false) {
      return navigator.clipboard.writeText(text).then(function () { return true; }, function () {
        return legacyCopy(text);
      });
    }
    return Promise.resolve(legacyCopy(text));
  }

  function legacyCopy(text) {
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.setAttribute('readonly', '');
    ta.style.position = 'fixed';
    ta.style.left = '-9999px';
    document.body.appendChild(ta);
    ta.select();
    var ok = false;
    try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
    ta.remove();
    return ok;
  }

  /* ---------- global delegated click listener ---------- */
  document.addEventListener('click', function (event) {
    // 1. Copy button
    var copyBtn = event.target.closest('[data-copy-target]');
    if (copyBtn) {
      var sel = copyBtn.getAttribute('data-copy-target') || '';
      var target = document.querySelector(sel);
      if (target) {
        var code = target.querySelector('code');
        var text = ((code ? code.textContent : target.textContent) || '').replace(/\n$/, '');
        copyText(text).then(function (ok) {
          if (!ok) return;
          var wordEl = copyBtn.querySelector('.copy-word') || copyBtn;
          copyBtn.setAttribute('data-done', '');
          wordEl.textContent = 'Copied';
          setTimeout(function () {
            copyBtn.removeAttribute('data-done');
            wordEl.textContent = 'Copy';
          }, 1600);
        });
      }
      return;
    }

    // 2. Direct theme toggle
    var themeToggle = event.target.closest('[data-theme-toggle]');
    if (themeToggle) {
      var isDark = document.documentElement.getAttribute('data-theme') === 'dark';
      var nextTheme = isDark ? 'light' : 'dark';
      try { localStorage.setItem('theme', nextTheme); } catch (e) { /* ignore */ }
      if (window.__setTheme) window.__setTheme(nextTheme);
      return;
    }

    // 3. Desktop nav click (instant visual active state)
    var desktopNavItem = event.target.closest('[data-desktop-nav-link]');
    if (desktopNavItem) {
      var allDesktopItems = document.querySelectorAll('[data-desktop-nav-link]');
      allDesktopItems.forEach(function (item) {
        if (item === desktopNavItem) {
          item.setAttribute('aria-current', 'page');
        } else {
          item.removeAttribute('aria-current');
        }
      });
    }

    // 4. Floating nav click (instant visual gliding)
    var navItem = event.target.closest('.floatnav [data-nav-item]');
    if (navItem) {
      var floatnav = navItem.closest('.floatnav');
      if (floatnav) {
        var pill = floatnav.querySelector('[data-nav-pill]');
        if (pill) {
          pill.style.transform = 'translate3d(' + navItem.offsetLeft + 'px, 0, 0)';
          pill.style.width = navItem.offsetWidth + 'px';
          pill.style.opacity = '1';
        }
        var allItems = floatnav.querySelectorAll('[data-nav-item]');
        allItems.forEach(function (item) {
          if (item === navItem) {
            item.setAttribute('aria-current', 'page');
          } else {
            item.removeAttribute('aria-current');
          }
        });
      }
    }
  });

  /* ---------- accordion exclusivity ---------- */
  function initAccordions() {
    var accordions = document.querySelectorAll('details[data-faq]');
    accordions.forEach(function (group) {
      if (group._hasFaqListener) return;
      group._hasFaqListener = true;
      group.addEventListener('toggle', function () {
        if (!group.open) return;
        accordions.forEach(function (other) {
          if (other !== group) other.open = false;
        });
      });
    });
  }

  /* ---------- directional view transitions ---------- */
  var routes = ['/', '/how-to-use', '/troubleshooting'];

  function normalizePath(p) {
    if (!p) return '/';
    var path = p.split('#')[0].split('?')[0].replace(/\/+$/, '');
    return path === '' ? '/' : path;
  }

  document.addEventListener('astro:before-preparation', function (event) {
    var fromPath = normalizePath(window.location.pathname);
    var toUrl = new URL(event.to);
    var toPath = normalizePath(toUrl.pathname);

    var fromIdx = routes.indexOf(fromPath);
    var toIdx = routes.indexOf(toPath);

    var dir = 'forward';
    if (fromIdx !== -1 && toIdx !== -1) {
      dir = toIdx >= fromIdx ? 'forward' : 'backward';
    } else if (event.navigationType === 'traverse') {
      dir = 'backward';
    }

    document.documentElement.setAttribute('data-nav-direction', dir);
  });

  /* ---------- desktop navigation active states ---------- */
  function updateDesktopNav() {
    var desktopLinks = document.querySelectorAll('[data-desktop-nav-link]');
    if (!desktopLinks.length) return;

    var currentPath = normalizePath(window.location.pathname);
    desktopLinks.forEach(function (link) {
      var href = normalizePath(link.getAttribute('href') || '');
      var isCurrent = (href === '/' && currentPath === '/') ||
                      (href !== '/' && (currentPath === href || currentPath.startsWith(href + '/')));
      if (isCurrent) {
        link.setAttribute('aria-current', 'page');
      } else {
        link.removeAttribute('aria-current');
      }
    });
  }

  /* ---------- floating dock indicator ---------- */
  function updateFloatingNav(immediate) {
    var floatnav = document.querySelector('.floatnav');
    if (!floatnav) return;
    if (floatnav.offsetParent === null && window.getComputedStyle(floatnav).display === 'none') {
      return;
    }

    var pill = floatnav.querySelector('[data-nav-pill]');
    var links = floatnav.querySelectorAll('[data-nav-item]');
    if (!links.length) return;

    var currentPath = normalizePath(window.location.pathname);
    var activeLink = null;

    links.forEach(function (link) {
      var href = normalizePath(link.getAttribute('href') || '');
      var isCurrent = (href === '/' && currentPath === '/') ||
                      (href !== '/' && (currentPath === href || currentPath.startsWith(href + '/')));
      if (isCurrent) {
        link.setAttribute('aria-current', 'page');
        activeLink = link;
      } else {
        link.removeAttribute('aria-current');
      }
    });

    if (!activeLink) {
      if (pill) pill.style.opacity = '0';
      return;
    }

    if (pill) {
      if (immediate) {
        pill.style.transition = 'none';
      }
      var left = activeLink.offsetLeft;
      var width = activeLink.offsetWidth;
      pill.style.transform = 'translate3d(' + left + 'px, 0, 0)';
      pill.style.width = width + 'px';
      pill.style.opacity = '1';

      if (immediate) {
        pill.offsetHeight; // trigger reflow
        pill.style.transition = '';
      }
    }

    floatnav.setAttribute('data-ready', '');
  }

  window.addEventListener('resize', function () {
    updateFloatingNav(true);
  });

  /* ---------- lifecycle hooks ---------- */
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      updateDesktopNav();
      updateFloatingNav(true);
      initAccordions();
    });
  } else {
    updateDesktopNav();
    updateFloatingNav(true);
    initAccordions();
  }

  document.addEventListener('astro:page-load', function () {
    updateDesktopNav();
    updateFloatingNav(false);
    initAccordions();
  });
})();
