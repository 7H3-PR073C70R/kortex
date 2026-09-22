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
});

