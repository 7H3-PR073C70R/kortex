/**
 * Kortexify Shared Client Library (kx.js)
 * Theme, motion and small widgets shared by every page built on kx.css.
 * Mirrors the behaviour of the landing page (index.html).
 */
(() => {
  'use strict';

  const $ = (s, scope = document) => scope.querySelector(s);
  const $$ = (s, scope = document) => [...scope.querySelectorAll(s)];
  const root = document.documentElement;
  const rm = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const fine = matchMedia('(hover: hover)').matches;
  const wait = ms => new Promise(r => setTimeout(r, rm ? 0 : ms));

  // ---------------------------------------------------------------------------
  // Theme
  // ---------------------------------------------------------------------------
  function applyTheme(theme) {
    root.dataset.theme = theme;
    const meta = $('meta[name="theme-color"]');
    if (meta) meta.content = theme === 'light' ? '#F6F6F8' : '#0D0D0F';
    try { localStorage.setItem('kx-theme', theme); } catch (e) {}
    dispatchEvent(new CustomEvent('kx:themechange', { detail: { theme } }));
  }

  function initTheme() {
    try {
      const t = localStorage.getItem('kx-theme');
      if (t === 'dark' || t === 'light') root.dataset.theme = t;
    } catch (e) {}
    $$('#th, [data-theme-toggle]').forEach(btn => {
      btn.onclick = () => {
        const current = root.dataset.theme || (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
        applyTheme(current === 'dark' ? 'light' : 'dark');
      };
    });
  }

  // ---------------------------------------------------------------------------
  // Word-split headlines ([data-split]) and scroll reveals (.rv)
  // ---------------------------------------------------------------------------
  function split(el) {
    let i = 0;
    el.setAttribute('aria-label', el.textContent.replace(/\s+/g, ' ').trim());
    const walk = node => [...node.childNodes].forEach(c => {
      if (c.nodeType === 3) {
        const frag = document.createDocumentFragment();
        c.textContent.split(/(\s+)/).forEach(t => {
          if (!t.trim()) { frag.append(t); return; }
          const s = document.createElement('span');
          s.className = 'w';
          s.setAttribute('aria-hidden', 'true');
          const inner = document.createElement('i');
          inner.style.setProperty('--i', i++);
          inner.textContent = t;
          s.append(inner);
          frag.append(s);
        });
        c.replaceWith(frag);
      } else {
        walk(c);
      }
    });
    walk(el);
  }

  function initReveals() {
    $$('[data-split]').forEach(split);
    const targets = $$('.rv, [data-split]');
    if (rm || !('IntersectionObserver' in window)) {
      targets.forEach(el => el.classList.add('in'));
      return;
    }
    const io = new IntersectionObserver(es => es.forEach(e => {
      if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
    }), { threshold: .18 });
    targets.forEach(el => io.observe(el));
  }

  // ---------------------------------------------------------------------------
  // Hero glow, pill parallax, retention meter, magnetic buttons
  // ---------------------------------------------------------------------------
  function initMotion() {
    const pills = $$('[data-par]');
    const mv = $('#mv'), mp = $('#mp');
    let tick = 0;
    const frame = () => {
      tick = 0;
      const y = scrollY, h = root.scrollHeight - innerHeight, p = h > 0 ? Math.min(1, y / h) : 0;
      if (mv) mv.textContent = Math.round(38 + 58 * (1 - Math.pow(1 - p, 2))) + '%';
      if (mp) mp.style.strokeDashoffset = 1 - p;
      if (!rm) pills.forEach(e => e.style.setProperty('--y', (y * parseFloat(e.dataset.par)).toFixed(1) + 'px'));
    };
    addEventListener('scroll', () => { if (!tick) { tick = 1; requestAnimationFrame(frame); } }, { passive: true });
    addEventListener('resize', frame);
    frame();

    if (!fine || rm) return;
    $$('.hero').forEach(h => h.addEventListener('pointermove', e => {
      const r = h.getBoundingClientRect();
      h.style.setProperty('--mx', (e.clientX - r.left) + 'px');
      h.style.setProperty('--my', (e.clientY - r.top) + 'px');
    }));
    $$('[data-mag]').forEach(b => {
      b.addEventListener('pointermove', e => {
        const r = b.getBoundingClientRect();
        b.style.transform = `translate(${((e.clientX - r.left - r.width / 2) * .22).toFixed(1)}px,${((e.clientY - r.top - r.height / 2) * .32).toFixed(1)}px)`;
      });
      b.addEventListener('pointerleave', () => { b.style.transform = ''; });
    });
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------
  function initWidgets() {
    // Marquee: duplicate the track so the loop is seamless.
    $$('.mq > div').forEach(track => {
      track.append(...[...track.children].map(c => {
        const k = c.cloneNode(true);
        k.setAttribute('aria-hidden', 'true');
        return k;
      }));
    });

    // Audio wave bars.
    $$('[data-wave]').forEach(el => {
      el.innerHTML = Array.from({ length: +el.dataset.wave || 26 }, (_, k) =>
        `<i style="--k:${k};height:${(30 + Math.abs(Math.sin(k * 1.7)) * 70).toFixed(0)}%"></i>`).join('');
    });

    // Question palettes that fill in as the exam progresses.
    $$('[data-pal]').forEach(pal => {
      const n = +pal.dataset.pal || 20;
      pal.innerHTML = '<i></i>'.repeat(n);
      if (rm) { [...pal.children].slice(0, n / 2).forEach(x => x.classList.add('d')); return; }
      let i = 0;
      setInterval(() => {
        const d = pal.children;
        if (i >= n) { [...d].forEach(x => x.classList.remove('d')); i = 0; } else d[i++].classList.add('d');
      }, 650);
    });

    // Countdown clocks: data-countdown="mm:ss".
    $$('[data-countdown]').forEach(el => {
      const [m, s] = el.dataset.countdown.split(':').map(Number);
      const start = m * 60 + s;
      let left = start;
      const fmt = () => String(left / 60 | 0).padStart(2, '0') + ':' + String(left % 60).padStart(2, '0');
      el.textContent = fmt();
      if (!rm) setInterval(() => { left = left > 0 ? left - 1 : start; el.textContent = fmt(); }, 1000);
    });

    // Flip cards: [data-flip] wraps a .fl.
    $$('[data-flip]').forEach(card => {
      const fl = $('.fl', card);
      const flip = () => {
        const on = fl.classList.toggle('on');
        card.setAttribute('aria-pressed', on ? 'true' : 'false');
        card.dispatchEvent(new CustomEvent('kx:flip', { detail: { on } }));
      };
      card.addEventListener('click', flip);
      card.addEventListener('keydown', e => {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); flip(); }
      });
    });

    // Scripted chats: bubbles with data-type are typed out in order.
    $$('[data-chat]').forEach(chat => {
      const typ = (el, t) => new Promise(r => {
        if (rm) { el.textContent = t; return r(); }
        let i = 0;
        el.classList.add('cur');
        const k = setInterval(() => {
          el.textContent = t.slice(0, ++i);
          if (i >= t.length) { clearInterval(k); el.classList.remove('cur'); r(); }
        }, 24);
      });
      const run = async () => {
        for (const b of $$('.bub', chat)) {
          b.classList.add('in');
          const t = $('[data-type]', b);
          if (t) await typ(t, t.dataset.type);
          await wait(b.classList.contains('me') ? 800 : 900);
        }
      };
      new IntersectionObserver((es, o) => {
        if (!es[0].isIntersecting) return;
        o.disconnect();
        run();
      }, { threshold: .4 }).observe(chat);
    });

    // Staged reveals: children with .step light up one after another.
    $$('[data-steps]').forEach(box => {
      const steps = $$('.step', box);
      new IntersectionObserver(async (es, o) => {
        if (!es[0].isIntersecting) return;
        o.disconnect();
        for (const s of steps) { s.classList.add('on'); await wait(700); }
      }, { threshold: .4 }).observe(box);
    });

    // Table of contents highlighting for long-form pages.
    const toc = $$('.toc a');
    if (toc.length && 'IntersectionObserver' in window) {
      const byId = new Map(toc.map(a => [a.getAttribute('href').slice(1), a]));
      const io = new IntersectionObserver(es => es.forEach(e => {
        if (!e.isIntersecting) return;
        toc.forEach(a => a.classList.remove('on'));
        byId.get(e.target.id)?.classList.add('on');
      }), { rootMargin: '-30% 0px -60% 0px' });
      byId.forEach((_, id) => { const s = document.getElementById(id); if (s) io.observe(s); });
    }
  }

  // ---------------------------------------------------------------------------
  // Currency (USD / NGN) and billing period for pricing displays
  // ---------------------------------------------------------------------------
  function setCurrency(curr) {
    const c = curr === 'NGN' ? 'NGN' : 'USD';
    root.dataset.currency = c;
    try { localStorage.setItem('kx-currency', c); } catch (e) {}
    $$('[data-currency-toggle]').forEach(btn => {
      const on = btn.dataset.currencyToggle === c;
      btn.classList.toggle('active', on);
      btn.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
    const annual = root.dataset.billing === 'annual';
    $$('[data-price-usd]').forEach(el => {
      const usd = annual && el.dataset.priceUsdAnnual ? el.dataset.priceUsdAnnual : el.dataset.priceUsd;
      const ngn = annual && el.dataset.priceNgnAnnual ? el.dataset.priceNgnAnnual : el.dataset.priceNgn;
      const sym = $('.price-currency', el), amt = $('.price-amount', el);
      if (sym) sym.textContent = c === 'NGN' ? '₦' : '$';
      if (amt) amt.textContent = c === 'NGN' ? ngn : usd;
    });
    dispatchEvent(new CustomEvent('kx:currencychange', { detail: { currency: c } }));
  }

  function initCurrency() {
    if (!$('[data-currency-toggle]') && !$('[data-price-usd]')) return;
    let initial = 'USD';
    try {
      const stored = localStorage.getItem('kx-currency');
      if (stored === 'NGN' || stored === 'USD') {
        initial = stored;
      } else {
        const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || '';
        if (tz.includes('Lagos') || navigator.language.includes('NG')) initial = 'NGN';
      }
    } catch (e) {}
    setCurrency(initial);
    $$('[data-currency-toggle]').forEach(btn => { btn.onclick = () => setCurrency(btn.dataset.currencyToggle); });
  }

  function init() {
    if (rm) document.body.classList.add('rm');
    initTheme();
    initReveals();
    initMotion();
    initWidgets();
    initCurrency();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();

  window.Kortex = { applyTheme, setCurrency };
})();
