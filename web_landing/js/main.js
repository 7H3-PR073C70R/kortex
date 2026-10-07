/**
 * KORTEX INTERACTIVE WORKSPACE ENGINE
 * High-Tactility, Zero-Glow Architecture
 * KaTeX LaTeX Rendering, 3D Flashcard Engine, Boutique Palette Switcher & Theme Toggle
 */

document.addEventListener('DOMContentLoaded', () => {
  const htmlRoot = document.documentElement;

  const themeToggleBtn = document.getElementById('themeToggleBtn');

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

  document.addEventListener('keydown', (e) => {
    if (e.code === 'Space' && document.activeElement === flashcardElement) {
      e.preventDefault();
      toggleFlip();
    }
  });

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

      currentCardIndex = (currentCardIndex + 1) % demoCards.length;

      if (flashcardElement) {
        flashcardElement.classList.remove('flipped');
      }
      setTimeout(renderCurrentCard, 180);
    });
  });

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

  const SUPABASE_URL    = 'https://mongizqfijuhycdxltpw.supabase.co';
  const SUPABASE_ANON   = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vbmdpenFmaWp1aHljZHhsdHB3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxMjk0ODksImV4cCI6MjEwMzcwNTQ4OX0.WdbPP0hWHnm2P7IWOOPOPv8emJsNql2jf5z6XnPa0wg';
  const NEWSLETTER_URL  = `${SUPABASE_URL}/functions/v1/subscribe-newsletter`;

  const initNewsletterForm = (form) => {
    const emailEl  = form.querySelector('[data-nl-email]');
    const statusEl = form.querySelector('[data-nl-status]');
    const btnEl    = form.querySelector('[data-nl-btn]');
    const btnTxt   = form.querySelector('[data-nl-btn-text]');
    const source   = form.getAttribute('data-newsletter-form') || 'landing_page';
    const idleLabel = btnTxt ? btnTxt.textContent.trim() : 'Notify Me';

    const setBtn = (state) => {
      if (!btnEl) return;
      if (state === 'loading') {
        btnEl.disabled = true;
        if (btnTxt) btnTxt.textContent = 'Joining…';
      } else if (state === 'done') {
        btnEl.disabled = true;
        if (btnTxt) btnTxt.textContent = 'You\'re in! ✓';
      } else {
        btnEl.disabled = false;
        if (btnTxt) btnTxt.textContent = idleLabel;
      }
    };

    const showStatus = (type, msg) => {
      if (!statusEl) return;
      statusEl.classList.remove('success', 'error');
      statusEl.classList.add(type);
      statusEl.textContent = msg;
    };

    form.addEventListener('submit', async (e) => {
      e.preventDefault();

      const email    = emailEl ? emailEl.value.trim() : '';
      const hpEl     = form.querySelector('[data-nl-hp]');
      const honeypot = hpEl ? hpEl.value : '';

      if (!email) {
        showStatus('error', 'Please enter your email address.');
        return;
      }

      setBtn('loading');

      try {
        const res = await fetch(NEWSLETTER_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': SUPABASE_ANON,
            'Authorization': `Bearer ${SUPABASE_ANON}`,
          },
          body: JSON.stringify({ email, source, hp: honeypot }),
        });

        const data = await res.json().catch(() => ({}));

        if (!res.ok) {
          throw new Error(data.error || `Submission failed (${res.status}). Please try again.`);
        }

        try {
          window.KortexSecurityEngine?.saveNewsletterEmail(email, source);
        } catch (_) { /* ignore localStorage errors */ }

        if (emailEl) emailEl.value = '';
        setBtn('done');
        showStatus('success', '✓ You\'re on the list! We\'ll send you updates as we build.');

      } catch (err) {
        setBtn('idle');
        showStatus('error', err.message || 'Something went wrong. Please try again.');
      }
    });
  };

  document.querySelectorAll('[data-newsletter-form]').forEach(initNewsletterForm);

  
  const intTabs = document.querySelectorAll('.int-tab');
  const docBadge = document.querySelector('.doc-badge');
  const formulaCode = document.querySelector('.formula-code');
  const miniFlashcard = document.getElementById('miniFlashcard');
  const miniCardFrontText = document.getElementById('miniCardFrontText');
  const miniCardBackText = document.getElementById('miniCardBackText');

  /* Renders a string with $...$ math delimiters into an element using KaTeX.
     Falls back to plain text if the KaTeX CDN is unavailable. */
  const renderMathText = (el, str) => {
    if (!el || !str) return;
    el.textContent = '';
    str.split('$').forEach((seg, i) => {
      if (!seg) return;
      if (i % 2 === 1 && window.katex) {
        const span = document.createElement('span');
        try {
          window.katex.render(seg, span, { displayMode: false, throwOnError: false });
        } catch (e) {
          span.textContent = seg;
        }
        el.appendChild(span);
      } else {
        el.appendChild(document.createTextNode(seg));
      }
    });
  };

  const ingestData = {
    pdf: {
      badge: 'Calculus_III_Notes.pdf',
      code: '$\\int x \\cdot e^x \\, dx = (x - 1)e^x + C$',
      front: 'What is the integration by parts formula for $\\int u \\, dv$?',
      back: '$\\int u \\, dv = uv - \\int v \\, du$'
    },
    ocr: {
      badge: 'Physics_Blackboard.jpg (Photo)',
      code: '$E^2 = (pc)^2 + (m_0 c^2)^2$',
      front: 'What is the relativistic energy-momentum relation?',
      back: '$E^2 = p^2c^2 + m_0^2c^4$'
    },
    slides: {
      badge: 'CHEM_201_Lecture_Slides.pptx (Slides)',
      code: '$6\\text{CO}_2 + 6\\text{H}_2\\text{O} \\xrightarrow{\\text{light}} \\text{C}_6\\text{H}_{12}\\text{O}_6 + 6\\text{O}_2$',
      front: 'What are the net inputs and outputs of oxygenic photosynthesis?',
      back: 'Inputs $6\\,\\text{CO}_2 + 6\\,\\text{H}_2\\text{O}$, outputs $\\text{C}_6\\text{H}_{12}\\text{O}_6 + 6\\,\\text{O}_2$'
    }
  };

  const applyIngest = (mode) => {
    const data = ingestData[mode];
    if (!data) return;
    if (docBadge) docBadge.textContent = data.badge;
    renderMathText(formulaCode, data.code);
    renderMathText(miniCardFrontText, data.front);
    renderMathText(miniCardBackText, data.back);
  };

  /* Render the default tab's math on load, not just on click */
  applyIngest('pdf');

  /* Exam prompt uses real math typesetting too */
  renderMathText(document.querySelector('.exam-question-prompt'), 'A 2.0 kg object moves with velocity $v(t) = 3t^2 + 2$ m/s. What is the net force acting on it at $t = 2$ s?');

  intTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      intTabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      applyIngest(tab.getAttribute('data-tab'));
      if (miniFlashcard) miniFlashcard.classList.remove('flipped');
    });
  });

  if (miniFlashcard) {
    miniFlashcard.addEventListener('click', () => {
      miniFlashcard.classList.toggle('flipped');
    });
  }

  const fsrsButtons = document.querySelectorAll('.fsrs-rate-btn');
  const retentionVal = document.getElementById('retentionVal');
  const fsrsStatusMsg = document.getElementById('fsrsStatusMsg');

  /* The forgetting curve reacts to the tapped rating: each grade redraws a
     different decay shape, with review dots placed at realistic spacing */
  const rtCurve = document.getElementById('rtCurve');
  const rtNodes = document.getElementById('rtNodes');
  const motionReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const rtPlans = {
    again: { d: 'M44 48 C 86 66, 106 128, 152 144 S 262 150, 356 150', stops: [0.07] },
    hard:  { d: 'M44 46 C 102 62, 130 134, 198 146 S 292 150, 356 150', stops: [0.12, 0.3] },
    good:  { d: 'M44 44 C 120 66, 150 150, 356 150', stops: [0.15, 0.38, 0.6] },
    easy:  { d: 'M44 42 C 165 58, 215 146, 356 150', stops: [0.2, 0.45, 0.68, 0.9] }
  };

  const drawRetentionPlan = (rating, animate) => {
    const plan = rtPlans[rating];
    if (!plan || !rtCurve || !rtNodes) return;

    rtCurve.setAttribute('d', plan.d);
    const len = rtCurve.getTotalLength();

    rtNodes.innerHTML = '';
    plan.stops.forEach((stop) => {
      const p = rtCurve.getPointAtLength(len * stop);
      const dot = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      dot.setAttribute('class', 'rt-node');
      dot.setAttribute('cx', p.x.toFixed(1));
      dot.setAttribute('cy', p.y.toFixed(1));
      dot.setAttribute('r', '6');
      rtNodes.appendChild(dot);
    });

    if (animate && !motionReduced && typeof rtCurve.animate === 'function') {
      rtCurve.animate(
        [{ strokeDashoffset: 1 }, { strokeDashoffset: 0 }],
        { duration: 750, easing: 'cubic-bezier(0.16, 1, 0.3, 1)' }
      );
      rtNodes.querySelectorAll('.rt-node').forEach((dot, i) => {
        dot.animate(
          [{ opacity: 0, transform: 'scale(0.3)' }, { opacity: 1, transform: 'scale(1)' }],
          { duration: 320, delay: 380 + i * 130, easing: 'cubic-bezier(0.16, 1, 0.3, 1)', fill: 'backwards' }
        );
      });
    }
  };

  /* Draw the default "Good" plan once on load */
  drawRetentionPlan('good', true);

  const fsrsFeedback = {
    again: {
      retention: '45%',
      msg: '⚠️ No problem, that one is tricky. We will show it again in <strong>10 minutes</strong> so it sticks.'
    },
    hard: {
      retention: '78%',
      msg: '⚡ You got there with effort. We will check on it again <strong>tomorrow</strong>.'
    },
    good: {
      retention: '94%',
      msg: '✓ Solid recall. Your next review is set for <strong>Thursday (3 days)</strong>.'
    },
    easy: {
      retention: '99%',
      msg: '🌟 You have this one. We will hold off for <strong>10 days</strong> and bring it back later.'
    }
  };

  fsrsButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      fsrsButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const rating = btn.getAttribute('data-rating');
      const info = fsrsFeedback[rating];
      if (info) {
        if (retentionVal) retentionVal.textContent = info.retention;
        if (fsrsStatusMsg) fsrsStatusMsg.innerHTML = info.msg;
        drawRetentionPlan(rating, true);
      }
    });
  });

  const examOptBtns = document.querySelectorAll('.exam-opt-btn');
  const examFeedbackBox = document.getElementById('examFeedbackBox');
  const feedbackStatus = document.getElementById('feedbackStatus');
  const feedbackExplanation = document.getElementById('feedbackExplanation');
  const examTimer = document.getElementById('examTimer');

  let timerSecs = 45;
  if (examTimer) {
    setInterval(() => {
      if (timerSecs > 0) {
        timerSecs--;
        const m = String(Math.floor(timerSecs / 60)).padStart(2, '0');
        const s = String(timerSecs % 60).padStart(2, '0');
        examTimer.textContent = `${m}:${s}`;
      }
    }, 1000);
  }

  examOptBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const isCorrect = btn.getAttribute('data-correct') === 'true';
      examOptBtns.forEach(b => {
        b.classList.remove('correct', 'wrong');
      });

      if (isCorrect) {
        btn.classList.add('correct');
        if (feedbackStatus) {
          feedbackStatus.className = 'feedback-status success';
          feedbackStatus.textContent = '✓ Correct! +100 Mastery XP';
        }
        if (feedbackExplanation) {
          renderMathText(feedbackExplanation, 'Acceleration $a = \\frac{dv}{dt} = 6t$, so at $t = 2$ s, $a = 12\\,\\text{m/s}^2$. Then $F = ma = 2.0 \\times 12 = 24\\,\\text{N}$.');
        }
      } else {
        btn.classList.add('wrong');
        const correctBtn = document.querySelector('.exam-opt-btn[data-correct="true"]');
        if (correctBtn) correctBtn.classList.add('correct');
        if (feedbackStatus) {
          feedbackStatus.className = 'feedback-status error';
          feedbackStatus.textContent = '✗ Incorrect. Automatically added to your review deck!';
        }
        if (feedbackExplanation) {
          renderMathText(feedbackExplanation, 'Remember $F = m\\frac{dv}{dt}$. The derivative of $3t^2 + 2$ is $6t$. At $t = 2$, $a = 12$, so $F = 2 \\times 12 = 24\\,\\text{N}$.');
        }
      }

      if (examFeedbackBox) {
        examFeedbackBox.style.display = 'block';
      }
    });
  });

  // ── Smart OS Auto-Detection & Download Configuration ──
  const OS_CONFIG = {
    mac: {
      name: 'macOS',
      title: 'Download for Mac',
      sub: 'v1.0.6 • Universal .DMG',
      navText: 'Download for Mac',
      url: 'https://pub-48d140cd04784f4b93fd2941eedd7223.r2.dev/downloads/Kortex-macOS-latest.dmg',
      iconSvg: '<svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.32c.67-.82 1.13-1.97.99-3.12-.98.04-2.19.66-2.88 1.47-.62.73-1.17 1.9-.1 3.02 1.1.09 2.32-.55 2.99-1.37z"/></svg>'
    },
    windows: {
      name: 'Windows',
      title: 'Download for Windows',
      sub: 'v1.0.6 • Installer & .EXE',
      navText: 'Download for Windows',
      url: 'https://pub-48d140cd04784f4b93fd2941eedd7223.r2.dev/downloads/Kortex-Windows-latest.exe',
      iconSvg: '<svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-13.051-1.851"/></svg>'
    },
    linux: {
      name: 'Linux',
      title: 'Download for Linux',
      sub: 'v1.0.6 • x86_64 .TAR.GZ',
      navText: 'Download for Linux',
      url: 'https://pub-48d140cd04784f4b93fd2941eedd7223.r2.dev/downloads/Kortex-Linux-latest.tar.gz',
      iconSvg: '<svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><path d="M12.002 0c-2.88 0-4.757 2.222-4.757 5.167 0 2.28 1.106 4.316 2.052 6.136.634 1.218 1.256 2.457 1.256 3.697 0 1.257-1.127 2.278-2.518 2.278-1.074 0-2.002-.62-2.39-1.532l-2.03.626c.72 1.83 2.509 3.056 4.42 3.056 2.68 0 4.67-2.046 4.67-4.428 0-1.745-.788-3.23-1.5-4.577-.732-1.393-1.423-2.698-1.423-4.257 0-1.85 1.163-3.017 2.218-3.017 1.056 0 2.22 1.166 2.22 3.017 0 1.56-.69 2.864-1.423 4.257-.712 1.347-1.5 2.832-1.5 4.577 0 2.382 1.99 4.428 4.67 4.428 1.91 0 3.7-1.226 4.42-3.056l-2.03-.626c-.388.912-1.316 1.532-2.39 1.532-1.39 0-2.518-1.02-2.518-2.278 0-1.24.622-2.479 1.256-3.697.946-1.82 2.052-3.856 2.052-6.136C16.76 2.222 14.882 0 12.002 0z"/></svg>'
    }
  };

  const userAgent = navigator.userAgent.toLowerCase();
  const platform = navigator.platform ? navigator.platform.toLowerCase() : '';
  let detectedOS = 'mac';
  if (userAgent.includes('win') || platform.includes('win')) {
    detectedOS = 'windows';
  } else if (userAgent.includes('linux') || userAgent.includes('x11') || platform.includes('linux')) {
    detectedOS = 'linux';
  } else if (userAgent.includes('mac') || userAgent.includes('darwin') || platform.includes('mac')) {
    detectedOS = 'mac';
  }

  const osConfig = OS_CONFIG[detectedOS] || OS_CONFIG.mac;

  // 1. Update Hero Main Download Button
  const heroMainDownloadBtn = document.getElementById('heroMainDownloadBtn');
  const heroDownloadIcon = document.getElementById('heroDownloadIcon');
  const heroDownloadTitle = document.getElementById('heroDownloadTitle');
  const heroDownloadSub = document.getElementById('heroDownloadSub');

  if (heroMainDownloadBtn) {
    heroMainDownloadBtn.setAttribute('href', osConfig.url);
    if (heroDownloadTitle) heroDownloadTitle.textContent = osConfig.title;
    if (heroDownloadSub) heroDownloadSub.textContent = osConfig.sub;
    if (heroDownloadIcon) heroDownloadIcon.innerHTML = osConfig.iconSvg;
  }

  // 2. Update Header Download Button
  const headerDownloadBtn = document.getElementById('headerDownloadBtn');
  const headerDownloadText = document.getElementById('headerDownloadText');
  if (headerDownloadBtn) {
    headerDownloadBtn.setAttribute('href', '#download');
    if (headerDownloadText) headerDownloadText.textContent = 'Download App';
  }

  // 3. Dropdown Menu Toggle
  const dropdownBtn = document.getElementById('heroDropdownToggleBtn');
  const dropdownMenu = document.getElementById('heroDownloadMenu');

  if (dropdownBtn && dropdownMenu) {
    dropdownBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      const isOpen = dropdownMenu.classList.contains('show');
      dropdownMenu.classList.toggle('show', !isOpen);
      dropdownBtn.setAttribute('aria-expanded', String(!isOpen));
    });

    document.addEventListener('click', () => {
      dropdownMenu.classList.remove('show');
      dropdownBtn.setAttribute('aria-expanded', 'false');
    });
  }

  // 4. Highlight Detected OS Card
  const downloadCards = document.querySelectorAll('.download-card');
  downloadCards.forEach((card) => {
    if (card.getAttribute('data-os') === detectedOS) {
      card.classList.add('highlight-os');
    }
  });

  // 5. Download OS Filter Tabs
  const osTabs = document.querySelectorAll('.download-os-tab');
  osTabs.forEach((tab) => {
    tab.addEventListener('click', () => {
      const targetOs = tab.getAttribute('data-os-tab');
      osTabs.forEach(t => {
        t.classList.remove('active');
        t.setAttribute('aria-selected', 'false');
      });
      tab.classList.add('active');
      tab.setAttribute('aria-selected', 'true');

      downloadCards.forEach((card) => {
        if (targetOs === 'all' || card.getAttribute('data-os') === targetOs) {
          card.style.display = 'flex';
          if (targetOs !== 'all' && card.getAttribute('data-os') === targetOs) {
            card.classList.add('highlight-os');
          }
        } else {
          card.style.display = 'none';
        }
      });
    });
  });
});

