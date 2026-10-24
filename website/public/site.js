/* Site interactions, event-delegated with Astro ClientRouter support.
   1. copy buttons  2. dialog sheets (CLI flags + theme picker)
   3. accordion exclusivity (details)  4. directional view transitions
   5. floating dock indicator animation */
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

  /* ---------- dialog sheets ---------- */
  function getSheet() {
    return document.getElementById('sheet');
  }

  var sheetOpener = null;

  function fillSheet(selector) {
    var sheet = getSheet();
    var tpl = document.querySelector(selector);
    if (!sheet || !tpl || tpl.tagName !== 'TEMPLATE') return;
    var body = document.getElementById('sheet-body');
    if (!body) return;
    body.replaceChildren(tpl.content.cloneNode(true));
    var heading = body.querySelector('h2');
    if (heading) {
      heading.id = 'sheet-heading';
      sheet.setAttribute('aria-labelledby', 'sheet-heading');
    }
  }

  function openSheet(selector, opener) {
    var sheet = getSheet();
    if (!sheet) return;
    sheetOpener = opener;
    fillSheet(selector);
    if (sheet.open) return;
    sheet.showModal();
  }

  function closeSheet() {
    var sheet = getSheet();
    if (sheet && sheet.open) sheet.close();
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

    // 3. Dialog sheets
    var opener = event.target.closest('[data-open-sheet]');
    if (opener) {
      openSheet(opener.getAttribute('data-open-sheet'), opener);
      return;
    }
    if (event.target.closest('[data-sclose]')) {
      closeSheet();
      return;
    }

    // 4. Backdrop click on sheet
    var sheet = getSheet();
    if (sheet && event.target === sheet) {
      closeSheet();
      return;
    }

    var choice = event.target.closest('[data-theme-choice]');
    if (choice) {
      var value = choice.getAttribute('data-theme-choice') || 'light';
      try { localStorage.setItem('theme', value); } catch (e) { /* ignore */ }
      if (window.__setTheme) window.__setTheme(value);
      if (sheet) {
        sheet.querySelectorAll('[data-theme-choice]').forEach(function (b) {
          b.setAttribute('aria-checked', String(b === choice));
        });
      }
      setTimeout(closeSheet, 320);
      return;
    }

    // 5. Floating nav click (instant visual gliding)
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

  // Dialog close focus restore
  document.addEventListener('close', function (event) {
    if (event.target && event.target.id === 'sheet') {
      if (sheetOpener) sheetOpener.focus();
      sheetOpener = null;
    }
  }, true);

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

  /* ---------- floating dock indicator ---------- */
  function updateFloatingNav(immediate) {
    var floatnav = document.querySelector('.floatnav');
    if (!floatnav) return;

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
      updateFloatingNav(true);
      initAccordions();
    });
  } else {
    updateFloatingNav(true);
    initAccordions();
  }

  document.addEventListener('astro:page-load', function () {
    updateFloatingNav(false);
    initAccordions();
  });
})();
