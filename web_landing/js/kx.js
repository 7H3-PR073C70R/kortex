/**
 * Kortexify Shared Client Library (kx.js)
 * High-performance, zero-dependency theme management, accessible widgets, and interactions.
 */
(() => {
  'use strict';

  const $ = (s, scope = document) => scope.querySelector(s);
  const $$ = (s, scope = document) => [...scope.querySelectorAll(s)];
  const root = document.documentElement;
  const isReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ---------------------------------------------------------------------------
  // 1. Theme Hydration & Toggle
  // ---------------------------------------------------------------------------
  function getSystemTheme() {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  function applyTheme(theme) {
    root.dataset.theme = theme;
    const metaTheme = $('meta[name="theme-color"]');
    if (metaTheme) {
      metaTheme.content = theme === 'dark' ? '#0D0D0F' : '#F6F6F8';
    }
    try {
      localStorage.setItem('kx-theme', theme);
    } catch (e) {}

    window.dispatchEvent(new CustomEvent('kx:themechange', { detail: { theme } }));
  }

  function initTheme() {
    try {
      const stored = localStorage.getItem('kx-theme');
      if (stored === 'dark' || stored === 'light') {
        applyTheme(stored);
      }
    } catch (e) {}

    // Attach listeners to any theme toggle element
    const themeButtons = $$('#th, [data-theme-toggle]');
    themeButtons.forEach(btn => {
      btn.onclick = () => {
        const current = root.dataset.theme || getSystemTheme();
        const next = current === 'dark' ? 'light' : 'dark';
        applyTheme(next);
      };
    });

    // Listen for OS theme preference changes if user hasn't explicitly locked one
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      try {
        if (!localStorage.getItem('kx-theme')) {
          applyTheme(e.matches ? 'dark' : 'light');
        }
      } catch (err) {}
    });
  }

  // ---------------------------------------------------------------------------
  // 2. Scroll Reveal Observer (.rv)
  // ---------------------------------------------------------------------------
  function initReveals() {
    if (isReducedMotion) {
      $$('.rv').forEach(el => el.classList.add('in'));
      return;
    }

    const observer = new IntersectionObserver((entries, obs) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('in');
          obs.unobserve(entry.target);
        }
      });
    }, { threshold: 0.14 });

    $$('.rv').forEach(el => observer.observe(el));
  }

  // ---------------------------------------------------------------------------
  // 3. Magnetic Hover Buttons ([data-mag])
  // ---------------------------------------------------------------------------
  function initMagneticButtons() {
    if (isReducedMotion || !window.matchMedia('(hover: hover)').matches) return;

    $$('[data-mag]').forEach(btn => {
      btn.addEventListener('pointermove', (e) => {
        const rect = btn.getBoundingClientRect();
        const x = (e.clientX - rect.left - rect.width / 2) * 0.22;
        const y = (e.clientY - rect.top - rect.height / 2) * 0.32;
        btn.style.transform = `translate(${x.toFixed(1)}px, ${y.toFixed(1)}px)`;
      });

      btn.addEventListener('pointerleave', () => {
        btn.style.transform = '';
      });
    });
  }

  // ---------------------------------------------------------------------------
  // 4. Currency Switcher (USD $ / NGN ₦)
  // ---------------------------------------------------------------------------
  function setCurrency(curr) {
    const validCurr = (curr === 'NGN' || curr === 'USD') ? curr : 'USD';
    root.dataset.currency = validCurr;

    try {
      localStorage.setItem('kx-currency', validCurr);
    } catch (e) {}

    // Update switcher button active state
    $$('[data-currency-toggle]').forEach(btn => {
      const match = btn.dataset.currencyToggle === validCurr;
      btn.classList.toggle('active', match);
      btn.setAttribute('aria-pressed', match ? 'true' : 'false');
    });

    // Update pricing displays
    $$('[data-price-usd]').forEach(el => {
      const isAnnual = root.dataset.billing === 'annual';
      const usd = isAnnual && el.dataset.priceUsdAnnual ? el.dataset.priceUsdAnnual : el.dataset.priceUsd;
      const ngn = isAnnual && el.dataset.priceNgnAnnual ? el.dataset.priceNgnAnnual : el.dataset.priceNgn;
      const symbol = validCurr === 'NGN' ? '₦' : '$';
      const amount = validCurr === 'NGN' ? ngn : usd;

      const currencySymbolEl = el.querySelector('.price-currency');
      const amountEl = el.querySelector('.price-amount');

      if (currencySymbolEl) currencySymbolEl.textContent = symbol;
      if (amountEl) amountEl.textContent = amount;
    });

    window.dispatchEvent(new CustomEvent('kx:currencychange', { detail: { currency: validCurr } }));
  }

  function initCurrency() {
    let initialCurr = 'USD';
    try {
      const stored = localStorage.getItem('kx-currency');
      if (stored === 'NGN' || stored === 'USD') {
        initialCurr = stored;
      } else {
        // Detect Nigerian timezone/locale as default suggestion
        const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || '';
        if (tz.includes('Lagos') || navigator.language.includes('NG')) {
          initialCurr = 'NGN';
        }
      }
    } catch (e) {}

    setCurrency(initialCurr);

    $$('[data-currency-toggle]').forEach(btn => {
      btn.onclick = () => {
        setCurrency(btn.dataset.currencyToggle);
      };
    });
  }

  // ---------------------------------------------------------------------------
  // 5. Mobile Menu Drawer Toggle
  // ---------------------------------------------------------------------------
  function initMobileMenu() {
    const toggle = $('#nav-toggle');
    const menu = $('#nav-menu');
    if (!toggle || !menu) return;

    toggle.onclick = () => {
      const open = menu.classList.toggle('open');
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      toggle.setAttribute('aria-label', open ? 'Close navigation menu' : 'Open navigation menu');
    };

    // Close on link click
    $$('a', menu).forEach(link => {
      link.addEventListener('click', () => {
        menu.classList.remove('open');
        toggle.setAttribute('aria-expanded', 'false');
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------
  function init() {
    initTheme();
    initReveals();
    initMagneticButtons();
    initCurrency();
    initMobileMenu();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // Public API
  window.Kortex = {
    applyTheme,
    setCurrency
  };
})();
