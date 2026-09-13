/**
 * KORTEXIFY INTERACTIVE WORKSPACE ENGINE
 * High-Converting Architecture, KaTeX LaTeX Rendering, 3D Flashcard Engine, Theme Toggle & Waitlist
 */

document.addEventListener('DOMContentLoaded', () => {
  // --------------------------------------------------------------------------
  // 1. Dark / Light Theme Toggle Engine
  // --------------------------------------------------------------------------
  const themeToggleBtn = document.getElementById('themeToggleBtn');
  const htmlRoot = document.documentElement;

  // Retrieve saved preference or system preference
  const savedTheme = localStorage.getItem('kortexify_theme') ||
    (window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark');

  function applyTheme(theme) {
    htmlRoot.setAttribute('data-theme', theme);
    localStorage.setItem('kortexify_theme', theme);
    if (themeToggleBtn) {
      themeToggleBtn.setAttribute('aria-label', `Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`);
      themeToggleBtn.innerHTML = theme === 'dark'
        ? '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>'
        : '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>';
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
  // 2. Multi-Modal Workstation Tab Switcher
  // --------------------------------------------------------------------------
  const tabButtons = document.querySelectorAll('.workstation-tabs .tab-btn');
  const tabPanels = document.querySelectorAll('.tab-panel');

  tabButtons.forEach((btn) => {
    btn.addEventListener('click', () => {
      const targetTab = btn.getAttribute('data-tab');

      tabButtons.forEach((b) => b.classList.remove('active'));
      tabPanels.forEach((p) => p.classList.remove('active'));

      btn.classList.add('active');
      const activePanel = document.getElementById(`panel-${targetTab}`);
      if (activePanel) {
        activePanel.classList.add('active');
      }
    });
  });

  // --------------------------------------------------------------------------
  // 3. Interactive 3D Flashcard & KaTeX Render Engine
  // --------------------------------------------------------------------------
  const flashcardElement = document.getElementById('interactiveFlashcard');
  const flipTriggerBtn = document.getElementById('flipCardTrigger');
  const formulaFrontEl = document.getElementById('katexFrontFormula');
  const formulaBackEl = document.getElementById('katexBackFormula');
  const statIntervalEl = document.getElementById('fsrsStatInterval');
  const statStabilityEl = document.getElementById('fsrsStatStability');

  const demoCards = [
    {
      topic: 'Physics & Electromagnetism',
      question: 'Calculate the induced electromotive force (EMF) generated across a coil when magnetic flux changes with time:',
      frontFormula: '\\mathcal{E} = -\\frac{d\\Phi_B}{dt}',
      backExplanation: 'By Faraday-Lenz Law of Electromagnetic Induction, the induced EMF opposes the rate of magnetic flux change through the closed circuit.',
      backFormula: '\\mathcal{E} = -\\frac{d}{dt}(B \\cdot A \\cos(\\omega t)) = \\omega B A \\sin(\\omega t)',
      difficulty: 'High Yield'
    },
    {
      topic: 'Calculus & Kinematics',
      question: 'Derive position from uniform acceleration assuming initial speed $u$ and acceleration $a$:',
      frontFormula: 's(t) = \\int (u + at) \\, dt',
      backExplanation: 'Integrating velocity with respect to time over the interval $[0, t]$ gives displacement.',
      backFormula: 's = ut + \\frac{1}{2}at^2',
      difficulty: 'Core Foundation'
    },
    {
      topic: 'Chemistry & Thermodynamics',
      question: 'Determine the standard Gibbs free energy change and reaction spontaneity condition:',
      frontFormula: '\\Delta G^\\circ = \\Delta H^\\circ - T\\Delta S^\\circ',
      backExplanation: 'A chemical reaction is thermodynamically spontaneous at constant temperature and pressure when Gibbs free energy is strictly negative.',
      backFormula: '\\Delta G < 0 \\implies K_{eq} = \\exp\\left(-\\frac{\\Delta G^\\circ}{RT}\\right) > 1',
      difficulty: 'WAEC / SAT'
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
    if (window.katex) {
      if (formulaFrontEl) {
        try {
          window.katex.render(card.frontFormula, formulaFrontEl, { displayMode: true, throwOnError: false });
        } catch (e) {
          formulaFrontEl.textContent = card.frontFormula;
        }
      }
      if (formulaBackEl) {
        try {
          window.katex.render(card.backFormula, formulaBackEl, { displayMode: true, throwOnError: false });
        } catch (e) {
          formulaBackEl.textContent = card.backFormula;
        }
      }
    }
  }

  // Initial KaTeX render
  if (window.katex) {
    renderCurrentCard();
  } else {
    // Retry if KaTeX is loading asynchronously
    setTimeout(renderCurrentCard, 400);
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
      setTimeout(renderCurrentCard, 200);
    });
  });

  // --------------------------------------------------------------------------
  // 4. Dynamic Live User Counter
  // --------------------------------------------------------------------------
  const baseCount = 25420;
  const countElements = document.querySelectorAll('.social-proof-count');

  function updateCounts(val) {
    countElements.forEach((el) => {
      el.textContent = val.toLocaleString();
    });
  }

  let currentCount = parseInt(
    localStorage.getItem('kortexify_live_counter') || baseCount,
    10
  );
  updateCounts(currentCount);

  setInterval(() => {
    if (Math.random() > 0.65) {
      currentCount += Math.floor(Math.random() * 3) + 1;
      localStorage.setItem('kortexify_live_counter', currentCount);
      updateCounts(currentCount);
    }
  }, 14000);

  // --------------------------------------------------------------------------
  // 5. FAQ Accordion Interaction
  // --------------------------------------------------------------------------
  const faqItems = document.querySelectorAll('.faq-item');
  faqItems.forEach((item) => {
    const questionBtn = item.querySelector('.faq-question');
    if (questionBtn) {
      questionBtn.addEventListener('click', () => {
        const isActive = item.classList.contains('active');
        faqItems.forEach((f) => f.classList.remove('active'));
        if (!isActive) {
          item.classList.add('active');
        }
      });
    }
  });

  // --------------------------------------------------------------------------
  // 6. Waitlist & Instant Access Form Handling
  // --------------------------------------------------------------------------
  const waitlistForms = document.querySelectorAll('.waitlist-form');

  function isValidEmail(email) {
    const regex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
    return regex.test(String(email).toLowerCase());
  }

  function showFeedback(el, msg, type) {
    if (!el) return;
    el.textContent = msg;
    el.className = `waitlist-feedback ${type}`;
    el.style.display = 'block';
  }

  waitlistForms.forEach((form) => {
    const input = form.querySelector('.waitlist-input');
    const button = form.querySelector('.waitlist-button');
    const container = form.closest('.waitlist-card') || form.parentElement;
    const feedback = container ? container.querySelector('.waitlist-feedback') : null;

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = input.value.trim();

      if (!email) {
        showFeedback(feedback, 'Please enter your student or personal email.', 'error');
        input.focus();
        return;
      }

      if (!isValidEmail(email)) {
        showFeedback(feedback, 'Please enter a valid email address.', 'error');
        input.focus();
        return;
      }

      button.disabled = true;
      const originalText = button.innerHTML;
      button.innerHTML = 'Connecting...';

      try {
        const leads = JSON.parse(localStorage.getItem('kortexify_leads') || '[]');
        if (!leads.includes(email)) {
          leads.push(email);
          localStorage.setItem('kortexify_leads', JSON.stringify(leads));
          currentCount += 1;
          updateCounts(currentCount);
        }

        setTimeout(() => {
          button.disabled = false;
          button.innerHTML = originalText;
          showFeedback(
            feedback,
            'Success! Your early access invite is reserved. Check your inbox shortly.',
            'success'
          );
          input.value = '';
        }, 600);
      } catch (err) {
        button.disabled = false;
        button.innerHTML = originalText;
        showFeedback(feedback, 'Something went wrong. Please try again.', 'error');
      }
    });
  });
});
