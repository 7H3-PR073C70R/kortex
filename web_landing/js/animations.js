/**
 * KORTEX LANDING — SHARED MOTION SYSTEM
 * Premium, editorial motion. Transform/opacity only, GPU friendly.
 * Every continuous effect is disabled for reduced-motion and touch devices.
 */

document.addEventListener('DOMContentLoaded', () => {
  const root = document.documentElement;
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const isTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
  const canPointerMotion = !reducedMotion && !isTouch && window.matchMedia('(min-width: 840px)').matches;

  /* ----------------------------------------------------------------------
     1. Scroll reveals (single elements + staggered groups)
     ---------------------------------------------------------------------- */
  const revealTargets = document.querySelectorAll('.reveal-on-scroll, [data-reveal-group]');

  const reveal = (el) => {
    if (el.hasAttribute('data-reveal-group')) {
      el.classList.add('is-revealed');
    } else {
      el.classList.add('is-revealed');
    }
  };

  if ('IntersectionObserver' in window && !reducedMotion) {
    const revealObserver = new IntersectionObserver((entries, obs) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          reveal(entry.target);
          obs.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -8% 0px' });

    revealTargets.forEach((el) => revealObserver.observe(el));
  } else {
    // No JS motion / reduced motion: show everything immediately.
    revealTargets.forEach((el) => el.classList.add('is-revealed'));
  }

  /* ----------------------------------------------------------------------
     2. Count-up numbers (honest, verifiable stats only)
     ---------------------------------------------------------------------- */
  const counters = document.querySelectorAll('[data-countup]');

  const runCount = (el) => {
    const target = parseInt(el.getAttribute('data-countup'), 10) || 0;
    if (reducedMotion || target <= 0) {
      el.textContent = target.toLocaleString('en-US');
      return;
    }
    const duration = 1200;
    const start = performance.now();
    const tick = (now) => {
      const p = Math.min((now - start) / duration, 1);
      const eased = 1 - Math.pow(1 - p, 3); // ease-out cubic
      el.textContent = Math.round(target * eased).toLocaleString('en-US');
      if (p < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  };

  if ('IntersectionObserver' in window) {
    const countObserver = new IntersectionObserver((entries, obs) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          runCount(entry.target);
          obs.unobserve(entry.target);
        }
      });
    }, { threshold: 0.6 });
    counters.forEach((el) => countObserver.observe(el));
  } else {
    counters.forEach((el) => { el.textContent = (parseInt(el.getAttribute('data-countup'), 10) || 0).toLocaleString('en-US'); });
  }

  /* ----------------------------------------------------------------------
     3. Staged chat bubbles (Socratic tutor demo)
     ---------------------------------------------------------------------- */
  const chatGroups = document.querySelectorAll('.chat-dialogue-simulation');
  chatGroups.forEach((group) => {
    const bubbles = group.querySelectorAll('.chat-bubble');
    if (reducedMotion || !('IntersectionObserver' in window)) {
      bubbles.forEach((b) => b.classList.add('is-shown'));
      return;
    }
    const obs = new IntersectionObserver((entries, o) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          bubbles.forEach((b, i) => setTimeout(() => b.classList.add('is-shown'), 180 + i * 360));
          o.unobserve(entry.target);
        }
      });
    }, { threshold: 0.4 });
    obs.observe(group);
  });

  /* ----------------------------------------------------------------------
     4. Header elevation + scroll progress bar
     ---------------------------------------------------------------------- */
  const header = document.querySelector('.site-header');
  const progress = document.getElementById('scrollProgress');
  let ticking = false;

  const onScroll = () => {
    const y = window.scrollY || 0;
    if (header) header.classList.toggle('is-scrolled', y > 30);

    if (progress) {
      const docH = root.scrollHeight - window.innerHeight;
      const ratio = docH > 0 ? Math.min(y / docH, 1) : 0;
      progress.style.transform = `scaleX(${ratio})`;
    }
    ticking = false;
  };

  window.addEventListener('scroll', () => {
    if (!ticking) {
      requestAnimationFrame(onScroll);
      ticking = true;
    }
  }, { passive: true });
  onScroll();

  /* ----------------------------------------------------------------------
     5. Pointer tilt on featured cards (desktop, fine pointer)
     ---------------------------------------------------------------------- */
  if (canPointerMotion) {
    document.querySelectorAll('[data-tilt]').forEach((card) => {
      const maxTilt = 5;
      card.addEventListener('pointermove', (e) => {
        const rect = card.getBoundingClientRect();
        const px = (e.clientX - rect.left) / rect.width - 0.5;
        const py = (e.clientY - rect.top) / rect.height - 0.5;
        card.style.transform =
          `perspective(1000px) rotateX(${(-py * maxTilt).toFixed(2)}deg) rotateY(${(px * maxTilt).toFixed(2)}deg) translateY(-4px)`;
      });
      card.addEventListener('pointerleave', () => {
        card.style.transform = '';
      });
    });

    /* Magnetic primary CTAs */
    document.querySelectorAll('[data-magnetic]').forEach((btn) => {
      btn.addEventListener('pointermove', (e) => {
        const rect = btn.getBoundingClientRect();
        const x = e.clientX - rect.left - rect.width / 2;
        const y = e.clientY - rect.top - rect.height / 2;
        btn.style.transform = `translate(${x * 0.12}px, ${y * 0.18}px)`;
      });
      btn.addEventListener('pointerleave', () => { btn.style.transform = ''; });
    });

    /* Subtle scroll parallax (transform on dedicated wrappers only) */
    const parallaxEls = Array.from(document.querySelectorAll('[data-parallax]'));
    if (parallaxEls.length) {
      const speedFor = (el) => parseFloat(el.getAttribute('data-parallax')) || 0.06;
      let pTick = false;
      const applyParallax = () => {
        const vh = window.innerHeight;
        parallaxEls.forEach((el) => {
          const rect = el.getBoundingClientRect();
          const center = rect.top + rect.height / 2;
          const offset = (center - vh / 2) * -speedFor(el);
          el.style.transform = `translate3d(0, ${offset.toFixed(1)}px, 0)`;
        });
        pTick = false;
      };
      window.addEventListener('scroll', () => {
        if (!pTick) { requestAnimationFrame(applyParallax); pTick = true; }
      }, { passive: true });
      applyParallax();
    }
  }

  /* ----------------------------------------------------------------------
     6. Scroll spy for nav links
     ---------------------------------------------------------------------- */
  const navLinks = Array.from(document.querySelectorAll('.nav-link[data-navspy]'));
  if (navLinks.length && 'IntersectionObserver' in window) {
    const map = new Map();
    navLinks.forEach((link) => {
      const section = document.getElementById(link.getAttribute('data-navspy'));
      if (section) map.set(section, link);
    });

    const spy = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        const link = map.get(entry.target);
        if (!link) return;
        if (entry.isIntersecting) {
          navLinks.forEach((l) => l.classList.remove('is-active'));
          link.classList.add('is-active');
        }
      });
    }, { rootMargin: '-45% 0px -50% 0px', threshold: 0 });

    map.forEach((_link, section) => spy.observe(section));
  }
});
