/**
 * KORTEX LANDING PAGE ANIMATIONS & INTERACTIVE EFFECTS (MOBILE OPTIMIZED)
 */

document.addEventListener('DOMContentLoaded', () => {
  // 1. Scroll-Triggered Reveal Animations using IntersectionObserver
  const revealElements = document.querySelectorAll('.reveal-on-scroll');

  if ('IntersectionObserver' in window) {
    const revealObserver = new IntersectionObserver(
      (entries, observer) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-revealed');
            observer.unobserve(entry.target);
          }
        });
      },
      {
        root: null,
        threshold: 0.05, // Trigger as soon as 5% of element is visible on mobile
        rootMargin: '0px 0px -20px 0px',
      }
    );

    revealElements.forEach((el) => revealObserver.observe(el));

    // Fallback safety: ensure all elements are visible within 2.5s regardless of scroll state
    setTimeout(() => {
      revealElements.forEach((el) => el.classList.add('is-revealed'));
    }, 2500);
  } else {
    // Fallback for older browsers
    revealElements.forEach((el) => el.classList.add('is-revealed'));
  }

  // 2. Sticky Glassmorphism Header Scroll State
  const header = document.querySelector('.site-header');
  let lastScrollY = window.scrollY;

  window.addEventListener(
    'scroll',
    () => {
      const currentScrollY = window.scrollY;
      if (currentScrollY > 30) {
        header?.classList.add('is-scrolled');
      } else {
        header?.classList.remove('is-scrolled');
      }
      lastScrollY = currentScrollY;
    },
    { passive: true }
  );

  // 3. 3D Perspective Tilt on Product Mockup Card (Desktop Only - Disabled on Touch/Mobile)
  const mockupCard = document.querySelector('.product-mockup-card');
  const mockupWrapper = document.querySelector('.hero-mockup-wrapper');
  const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;

  if (mockupCard && mockupWrapper && !isTouchDevice && window.innerWidth >= 768) {
    mockupWrapper.addEventListener('mousemove', (e) => {
      const rect = mockupWrapper.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;

      const centerX = rect.width / 2;
      const centerY = rect.height / 2;

      const rotateX = ((y - centerY) / centerY) * -4;
      const rotateY = ((x - centerX) / centerX) * 4;

      mockupCard.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg)`;
    });

    mockupWrapper.addEventListener('mouseleave', () => {
      mockupCard.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg)';
    });
  }

  // 4. FAQ Accordion Interaction (Accessible with touch support)
  const faqItems = document.querySelectorAll('.faq-item');
  faqItems.forEach((item) => {
    const questionBtn = item.querySelector('.faq-question');
    questionBtn?.addEventListener('click', () => {
      const isOpen = item.classList.contains('is-open');

      // Close all other accordion items
      faqItems.forEach((other) => {
        if (other !== item) {
          other.classList.remove('is-open');
          other.querySelector('.faq-question')?.setAttribute('aria-expanded', 'false');
        }
      });

      if (isOpen) {
        item.classList.remove('is-open');
        questionBtn.setAttribute('aria-expanded', 'false');
      } else {
        item.classList.add('is-open');
        questionBtn.setAttribute('aria-expanded', 'true');
      }
    });
  });
});
