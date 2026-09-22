/**
 * KORTEX INTERACTIVE WORKSPACE ENGINE
 * High-Tactility, Zero-Glow Architecture
 * KaTeX LaTeX Rendering, 3D Flashcard Engine, Boutique Palette Switcher & Theme Toggle
 */

document.addEventListener('DOMContentLoaded', () => {
  const htmlRoot = document.documentElement;

  // --------------------------------------------------------------------------
  // 1. Dark / Light Theme Toggle Engine
  // --------------------------------------------------------------------------
  const themeToggleBtn = document.getElementById('themeToggleBtn');

  // Retrieve saved preference or system preference
  const savedTheme = localStorage.getItem('kortex_theme') ||
    (window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark');

  function applyTheme(theme) {
    htmlRoot.setAttribute('data-theme', theme);
    localStorage.setItem('kortex_theme', theme);
    if (themeToggleBtn) {
      themeToggleBtn.setAttribute('aria-label', `Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`);
      themeToggleBtn.innerHTML = theme === 'dark'
        ? '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>'
        : '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>';
    }
  }

  applyTheme(savedTheme);

  if (themeToggleBtn) {
    themeToggleBtn.addEventListener('click', () => {
      const currentTheme = htmlRoot.getAttribute('data-theme') || 'dark';
      const nextTheme = currentTheme === 'dark' ? 'light' : 'dark';
      applyTheme(nextTheme);
    });
  }

  // --------------------------------------------------------------------------
  // 2. Boutique Theme Preset Accent Switcher
  // --------------------------------------------------------------------------
  const accentDots = document.querySelectorAll('.accent-dot');
  const savedAccent = localStorage.getItem('kortex_accent') || 'sage';

  const accentMap = {
    sage: 'default',
    ochre: 'warm-ochre',
    moss: 'alpine-moss',
    bronze: 'deep-bronze',
    terracotta: 'slate-terracotta',
    quartz: 'quartz-cyan'
  };

  function applyAccent(accentKey) {
    const mappedAttr = accentMap[accentKey] || 'default';
    if (mappedAttr === 'default') {
      htmlRoot.removeAttribute('data-accent');
    } else {
      htmlRoot.setAttribute('data-accent', mappedAttr);
    }
    localStorage.setItem('kortex_accent', accentKey);

    accentDots.forEach((dot) => {
      if (dot.getAttribute('data-set-accent') === accentKey) {
        dot.classList.add('active');
      } else {
        dot.classList.remove('active');
      }
    });
  }

  applyAccent(savedAccent);

  accentDots.forEach((dot) => {
    dot.addEventListener('click', () => {
      const selected = dot.getAttribute('data-set-accent');
      if (selected) {
        applyAccent(selected);
      }
    });
  });

  // --------------------------------------------------------------------------
  // 3. Multi-Modal Workstation Tab Switcher
  // --------------------------------------------------------------------------
  const tabButtons = document.querySelectorAll('.workstation-tabs .tab-btn');
  const tabPanels = document.querySelectorAll('.tab-panel');

  tabButtons.forEach((btn) => {
    btn.addEventListener('click', () => {
      const targetTab = btn.getAttribute('data-tab');

      tabButtons.forEach((b) => {
        b.classList.remove('active');
        b.setAttribute('aria-selected', 'false');
      });
      tabPanels.forEach((p) => p.classList.remove('active'));

      btn.classList.add('active');
      btn.setAttribute('aria-selected', 'true');
      const activePanel = document.getElementById(`panel-${targetTab}`);
      if (activePanel) {
        activePanel.classList.add('active');
      }
    });
  });

  // --------------------------------------------------------------------------
  // 4. Interactive 3D Flashcard & KaTeX Render Engine
  // --------------------------------------------------------------------------
  const flashcardElement = document.getElementById('interactiveFlashcard');
  const flipTriggerBtn = document.getElementById('flipCardTrigger');
  const formulaFrontEl = document.getElementById('katexFrontFormula');
  const formulaBackEl = document.getElementById('katexBackFormula');
  const statIntervalEl = document.getElementById('fsrsStatInterval');
  const statStabilityEl = document.getElementById('fsrsStatStability');

  const demoCards = [
    {
      topic: 'Quick Question',
      question: 'Why do you forget things after reading them?',
      frontFormula: '',
      backExplanation: "Because reading isn't testing. Your brain only keeps information when you practice bringing it back out. Kortexify builds that exact practice for you.",
      backFormula: '',
      difficulty: 'General'
    },
    {
      topic: 'Physics',
      question: 'Calculate the induced electromotive force (EMF) generated across a coil when magnetic flux changes with time:',
      frontFormula: '\\mathcal{E} = -\\frac{d\\Phi_B}{dt}',
      backExplanation: 'By Faraday-Lenz Law of Electromagnetic Induction, the induced EMF opposes the rate of magnetic flux change through the closed circuit.',
      backFormula: '\\mathcal{E} = -\\frac{d}{dt}(B \\cdot A \\cos(\\omega t)) = \\omega B A \\sin(\\omega t)',
      difficulty: 'High Yield'
    },
    {
      topic: 'Mathematics',
      question: 'Find the roots of a quadratic equation:',
      frontFormula: 'ax^2 + bx + c = 0',
      backExplanation: 'The quadratic formula computes the solutions by completing the square.',
      backFormula: 'x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}',
      difficulty: 'Core Foundation'
    },
    {
      topic: 'Medicine',
      question: 'What is the primary function of the SA (sinoatrial) node in the heart?',
      frontFormula: '',
      backExplanation: 'The SA node acts as the natural pacemaker of the heart, generating electrical impulses that dictate the heart rate.',
      backFormula: '',
      difficulty: 'High Yield'
    },
    {
      topic: 'Chemistry',
      question: 'Determine the standard Gibbs free energy change and reaction spontaneity condition:',
      frontFormula: '\\Delta G^\\circ = \\Delta H^\\circ - T\\Delta S^\\circ',
      backExplanation: 'A chemical reaction is thermodynamically spontaneous at constant temperature and pressure when Gibbs free energy is strictly negative.',
      backFormula: '\\Delta G < 0',
      difficulty: 'High Yield'
    },
    {
      topic: 'Criminal Law',
      question: 'What are the two fundamental elements required to establish criminal liability?',
      frontFormula: '',
      backExplanation: 'Criminal liability typically requires both Actus Reus (the guilty act) and Mens Rea (the guilty mind or intent).',
      backFormula: '',
      difficulty: 'Core Foundation'
    }
  ];

  let currentCardIndex = 0;

  function renderCurrentCard() {
    const card = demoCards[currentCardIndex];
    const questionTextEl = document.getElementById('cardQuestionText');
    const answerTextEl = document.getElementById('cardAnswerText');
    const topicBadgeEl = document.getElementById('cardTopicBadge');

    if (questionTextEl) questionTextEl.textContent = card.question;
    if (answerTextEl) answerTextEl.textContent = card.backExplanation;
    if (topicBadgeEl) topicBadgeEl.textContent = card.topic;

    // KaTeX LaTeX rendering
    if (formulaFrontEl) {
      if (card.frontFormula) {
        formulaFrontEl.style.display = 'flex';
        if (window.katex) {
          try {
            window.katex.render(card.frontFormula, formulaFrontEl, { displayMode: true, throwOnError: false });
          } catch (e) {
            formulaFrontEl.textContent = card.frontFormula;
          }
        }
      } else {
        formulaFrontEl.style.display = 'none';
      }
    }
    
    if (formulaBackEl) {
      if (card.backFormula) {
        formulaBackEl.style.display = 'flex';
        if (window.katex) {
          try {
            window.katex.render(card.backFormula, formulaBackEl, { displayMode: true, throwOnError: false });
          } catch (e) {
            formulaBackEl.textContent = card.backFormula;
          }
        }
      } else {
        formulaBackEl.style.display = 'none';
      }
    }
  }

  // Initial KaTeX render
  if (window.katex) {
    renderCurrentCard();
  } else {
    setTimeout(renderCurrentCard, 350);
  }

  function toggleFlip() {
    if (flashcardElement) {
      flashcardElement.classList.toggle('flipped');
    }
  }

  if (flashcardElement) {
    flashcardElement.addEventListener('click', toggleFlip);
  }
  if (flipTriggerBtn) {
    flipTriggerBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      toggleFlip();
    });
  }

  // Keyboard navigation for card flip
  document.addEventListener('keydown', (e) => {
    if (e.code === 'Space' && document.activeElement === flashcardElement) {
      e.preventDefault();
      toggleFlip();
    }
  });

  // FSRS-6 Interactive Rating Buttons
  const ratingButtons = document.querySelectorAll('.rating-pill-btn');
  ratingButtons.forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const rating = btn.getAttribute('data-rating');

      let nextInterval = '3.5 days';
      let stability = '94%';

      if (rating === 'again') {
        nextInterval = '10 minutes';
        stability = '45%';
      } else if (rating === 'hard') {
        nextInterval = '1.2 days';
        stability = '78%';
      } else if (rating === 'good') {
        nextInterval = '3.5 days';
        stability = '94%';
      } else if (rating === 'easy') {
        nextInterval = '8.2 days';
        stability = '99%';
      }

      if (statIntervalEl) statIntervalEl.textContent = nextInterval;
      if (statStabilityEl) statStabilityEl.textContent = stability;

      // Cycle to next demo card
      currentCardIndex = (currentCardIndex + 1) % demoCards.length;

      // Reset card flip and render new content
      if (flashcardElement) {
        flashcardElement.classList.remove('flipped');
      }
      setTimeout(renderCurrentCard, 180);
    });
  });

  // --------------------------------------------------------------------------
  // 5. Dynamic Active User Counter
  // --------------------------------------------------------------------------
  const baseCount = 25420;
  const countElements = document.querySelectorAll('.social-proof-count');

  function updateCounts(val) {
    countElements.forEach((el) => {
      el.textContent = val.toLocaleString();
    });
  }

  let currentCount = parseInt(
    localStorage.getItem('kortex_live_counter') || baseCount,
    10
  );
  updateCounts(currentCount);

  setInterval(() => {
    if (Math.random() > 0.65) {
      currentCount += Math.floor(Math.random() * 3) + 1;
      localStorage.setItem('kortex_live_counter', currentCount);
      updateCounts(currentCount);
    }
  }, 16000);

  // --------------------------------------------------------------------------
  // 6. FAQ Accordion Interaction
  // --------------------------------------------------------------------------
  const faqItems = document.querySelectorAll('.faq-item');
  faqItems.forEach((item) => {
    const questionBtn = item.querySelector('.faq-question');
    if (questionBtn) {
      questionBtn.addEventListener('click', () => {
        const isActive = item.classList.contains('active');
        faqItems.forEach((f) => {
          f.classList.remove('active');
          const btn = f.querySelector('.faq-question');
          if (btn) btn.setAttribute('aria-expanded', 'false');
        });
        if (!isActive) {
          item.classList.add('active');
          questionBtn.setAttribute('aria-expanded', 'true');
        }
      });
    }
  });

  // --------------------------------------------------------------------------
  // 7. Landing Page Newsletter Subscription – Supabase Edge Function
  // --------------------------------------------------------------------------
  const SUPABASE_URL    = 'https://mongizqfijuhycdxltpw.supabase.co';
  const SUPABASE_ANON   = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vbmdpenFmaWp1aHljZHhsdHB3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxMjk0ODksImV4cCI6MjEwMzcwNTQ4OX0.WdbPP0hWHnm2P7IWOOPOPv8emJsNql2jf5z6XnPa0wg';
  const NEWSLETTER_URL  = `${SUPABASE_URL}/functions/v1/subscribe-newsletter`;

  const landingNewsletterForm   = document.getElementById('landingNewsletterForm');
  const landingNewsletterEmail  = document.getElementById('landingNewsletterEmail');
  const landingNewsletterStatus = document.getElementById('landingNewsletterStatus');
  const landingNewsletterBtn    = document.getElementById('landingNewsletterBtn');
  const landingNewsletterBtnTxt = document.getElementById('landingNewsletterBtnText');

  function setNewsletterBtn(state) {
    // state: 'idle' | 'loading' | 'done'
    if (!landingNewsletterBtn) return;
    if (state === 'loading') {
      landingNewsletterBtn.disabled = true;
      if (landingNewsletterBtnTxt) landingNewsletterBtnTxt.textContent = 'Joining…';
    } else if (state === 'done') {
      landingNewsletterBtn.disabled = true;
      if (landingNewsletterBtnTxt) landingNewsletterBtnTxt.textContent = 'You\'re in! ✓';
    } else {
      landingNewsletterBtn.disabled = false;
      if (landingNewsletterBtnTxt) landingNewsletterBtnTxt.textContent = 'Notify Me';
    }
  }

  function showNewsletterStatus(type, msg) {
    if (!landingNewsletterStatus) return;
    landingNewsletterStatus.className = `newsletter-status-box ${type}`;
    landingNewsletterStatus.textContent = msg;
  }

  if (landingNewsletterForm) {
    landingNewsletterForm.addEventListener('submit', async (e) => {
      e.preventDefault();

      const email    = landingNewsletterEmail ? landingNewsletterEmail.value.trim() : '';
      const honeypot = document.getElementById('nlHoneypot')?.value || '';

      if (!email) {
        showNewsletterStatus('error', 'Please enter your email address.');
        return;
      }

      setNewsletterBtn('loading');

      try {
        const res = await fetch(NEWSLETTER_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': SUPABASE_ANON,
            'Authorization': `Bearer ${SUPABASE_ANON}`,
          },
          body: JSON.stringify({ email, source: 'landing_page', hp: honeypot }),
        });

        const data = await res.json().catch(() => ({}));

        if (!res.ok) {
          throw new Error(data.error || `Submission failed (${res.status}). Please try again.`);
        }

        // Also save locally as offline cache / backup
        try {
          window.KortexSecurityEngine?.saveNewsletterEmail(email, 'landing_page');
        } catch (_) { /* ignore localStorage errors */ }

        if (landingNewsletterEmail) landingNewsletterEmail.value = '';
        setNewsletterBtn('done');
        showNewsletterStatus('success', '✓ You\'re on the list! We\'ll send you updates as we build.');

      } catch (err) {
        setNewsletterBtn('idle');
        showNewsletterStatus('error', err.message || 'Something went wrong. Please try again.');
      }
    });
  }
});
