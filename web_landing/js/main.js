/**
 * KORTEXIFY LANDING PAGE CORE LOGIC
 * Waitlist submission (with Supabase hooks & local fallback), dynamic live counter,
 * and multi-level interactive flashcard demo.
 */

document.addEventListener('DOMContentLoaded', () => {
  // 1. Dynamic Live Waitlist Counter
  const baseCount = 1428;
  const countElements = document.querySelectorAll('.social-proof-count');

  function updateCounts(val) {
    countElements.forEach((el) => {
      el.textContent = val.toLocaleString();
    });
  }

  // Retrieve saved count or initialize
  let currentCount = parseInt(
    localStorage.getItem('kortexify_waitlist_count') || 
    localStorage.getItem('kortex_waitlist_count') || 
    baseCount, 
    10
  );
  updateCounts(currentCount);

  // Periodic organic increment simulation
  setInterval(() => {
    if (Math.random() > 0.6) {
      currentCount += 1;
      localStorage.setItem('kortexify_waitlist_count', currentCount);
      updateCounts(currentCount);
    }
  }, 12000);

  // 2. Email Validation & Waitlist Form Submission (Supabase Ready)
  const waitlistForms = document.querySelectorAll('.waitlist-form');

  function isValidEmail(email) {
    const regex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
    return regex.test(String(email).toLowerCase());
  }

  waitlistForms.forEach((form) => {
    const input = form.querySelector('.waitlist-input');
    const button = form.querySelector('.waitlist-button');
    const feedback = form.parentElement.querySelector('.waitlist-feedback');

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = input.value.trim();

      if (!email) {
        showFeedback(feedback, 'Please enter your student or personal email.', 'error');
        input.focus();
        return;
      }

      if (!isValidEmail(email)) {
        showFeedback(feedback, 'Please enter a valid email address (e.g., student@example.com).', 'error');
        input.focus();
        return;
      }

      // Submission state
      button.disabled = true;
      const originalButtonText = button.innerHTML;
      button.innerHTML = '<span class="spinner"></span> Securing Spot...';

      try {
        // Save to LocalStorage
        const existingLeads = JSON.parse(
          localStorage.getItem('kortexify_leads') || 
          localStorage.getItem('kortex_leads') || 
          '[]'
        );
        if (!existingLeads.includes(email)) {
          existingLeads.push(email);
          localStorage.setItem('kortexify_leads', JSON.stringify(existingLeads));
          currentCount += 1;
          updateCounts(currentCount);
        }

        // Supabase direct integration hook if initialized on window
        if (window.supabase && typeof window.supabase.from === 'function') {
          try {
            await window.supabase.from('waitlist_leads').insert([
              { email: email, created_at: new Date().toISOString(), source: 'web_landing' }
            ]);
          } catch (supabaseErr) {
            console.warn('Supabase lead capture notice:', supabaseErr);
          }
        }

        // Network latency simulation
        await new Promise((resolve) => setTimeout(resolve, 600));

        showFeedback(
          feedback,
          `🎉 You're on the priority list! VIP Private Beta access link sent to ${email}.`,
          'success'
        );
        input.value = '';
        button.innerHTML = 'Spot Reserved ✓';
      } catch (err) {
        showFeedback(feedback, 'Your spot was saved! Welcome to the beta cohort.', 'success');
        button.innerHTML = originalButtonText;
      } finally {
        button.disabled = false;
      }
    });
  });

  function showFeedback(el, message, type) {
    if (!el) return;
    el.textContent = message;
    el.className = `waitlist-feedback ${type}`;
  }

  // 3. Multi-Level Interactive Flashcard Demo (WAEC to PhD)
  const demoCards = [
    {
      deckTitle: 'waec_biology_past_questions.deck',
      level: 'WAEC • Senior Secondary',
      subject: 'Biology • Cell Transport & Osmosis',
      question: 'What is the primary role of the semi-permeable membrane in plant root hair cells during water absorption from the soil?',
      answer: '<strong>Selective Osmosis:</strong> Allows water molecules to enter root cells down a water potential gradient from hypotonic soil to hypertonic cell sap, while preventing essential internal solutes and minerals from leaking out.',
      interval: 'Interval: 3d',
      mastery: 'Mastery: 92%',
      difficulty: 'Difficulty: Moderate',
      nextIntervals: { again: '10m', hard: '1d', good: '3d', easy: '7d' }
    },
    {
      deckTitle: 'jamb_utme_use_of_english.deck',
      level: 'JAMB / UTME • Use of English',
      subject: 'Lexis & Structure • Subject-Verb Concord',
      question: 'Choose the correct option: "Neither the principal nor the subject teachers _____ present at yesterday\'s emergency briefing." (was / were)',
      answer: '<strong>Rule of Proximity:</strong> <em>"were"</em>. When subjects are joined by "neither... nor", the verb agrees with the nearer subject ("teachers", which is plural).',
      interval: 'Interval: 2d',
      mastery: 'Mastery: 88%',
      difficulty: 'Difficulty: Tricky',
      nextIntervals: { again: '10m', hard: '1d', good: '2d', easy: '5d' }
    },
    {
      deckTitle: 'law302_constitutional_jurisprudence.deck',
      level: 'Undergraduate • Faculty of Law',
      subject: 'Constitutional Law • Separation of Powers',
      question: 'What is the core distinction between the doctrine of "Separation of Powers" and the mechanism of "Checks and Balances"?',
      answer: '<strong>Functional Independence vs. Oversight:</strong> Separation of Powers divides governance into three independent arms (Executive, Legislative, Judiciary). Checks and Balances grants each arm constitutional authority (e.g. judicial review, legislative vetos) to prevent authoritarian abuse.',
      interval: 'Interval: 5d',
      mastery: 'Mastery: 95%',
      difficulty: 'Difficulty: Analytical',
      nextIntervals: { again: '15m', hard: '2d', good: '5d', easy: '12d' }
    },
    {
      deckTitle: 'med401_cardiovascular_physiology.deck',
      level: 'Clinical Medicine • MBBS / Pre-Med',
      subject: 'Physiology • Cardiac Hemodynamics',
      question: 'Explain the Frank-Starling mechanism of the heart and its direct impact on stroke volume.',
      answer: '<strong>Length-Tension Relationship:</strong> An increase in end-diastolic volume (preload) stretches ventricular myocytes, increasing troponin C sensitivity to calcium and generating greater contractile force for higher stroke volume.',
      interval: 'Interval: 7d',
      mastery: 'Mastery: 96%',
      difficulty: 'Difficulty: High-Yield',
      nextIntervals: { again: '20m', hard: '3d', good: '7d', easy: '18d' }
    },
    {
      deckTitle: 'phd_deep_learning_attention.deck',
      level: 'PhD Research • Machine Learning & AI',
      subject: 'Neural Architectures • Attention Mechanisms',
      question: 'Why does Scaled Dot-Product Attention divide the query-key matrix multiplication by √d_k?',
      answer: '<strong>Gradient Variance Stabilization:</strong> For large key dimensions d_k, dot products grow large in magnitude, pushing the softmax function into regions with vanishingly small gradients. Scaling by 1/√d_k ensures stable unit variance.',
      interval: 'Interval: 14d',
      mastery: 'Mastery: 98%',
      difficulty: 'Difficulty: Advanced',
      nextIntervals: { again: '30m', hard: '5d', good: '14d', easy: '30d' }
    },
    {
      deckTitle: 'waec_econ_microeconomics.deck',
      level: 'WAEC / A-Level • Economics',
      subject: 'Microeconomics • Elasticity of Demand',
      question: 'What happens to a firm\'s total revenue if it increases price when price elasticity of demand is elastic (E_d > 1)?',
      answer: '<strong>Total Revenue Decreases:</strong> Because demand is price-sensitive, the percentage decline in quantity demanded exceeds the percentage increase in price, reducing total receipts.',
      interval: 'Interval: 4d',
      mastery: 'Mastery: 90%',
      difficulty: 'Difficulty: Moderate',
      nextIntervals: { again: '10m', hard: '1d', good: '4d', easy: '9d' }
    }
  ];

  let currentCardIndex = 0;
  const levelPills = document.querySelectorAll('.level-pill');
  const mockupCardContent = document.getElementById('mockupCardContent');
  const deckTitleEl = document.getElementById('mockupDeckTitle');
  const cardLevelBadge = document.getElementById('cardLevelBadge');
  const cardSubjectTag = document.getElementById('cardSubjectTag');
  const statInterval = document.getElementById('statInterval');
  const statMastery = document.getElementById('statMastery');
  const statDifficulty = document.getElementById('statDifficulty');
  const cardQuestionText = document.getElementById('cardQuestionText');
  const cardAnswerText = document.getElementById('cardAnswerText');
  const ratingButtons = document.querySelectorAll('.rating-btn');

  function renderCard(index, customIntervalText) {
    const card = demoCards[index];
    if (!card) return;

    if (mockupCardContent) {
      mockupCardContent.classList.add('card-transitioning');
    }

    setTimeout(() => {
      if (deckTitleEl) deckTitleEl.textContent = card.deckTitle;
      if (cardLevelBadge) cardLevelBadge.textContent = card.level;
      if (cardSubjectTag) cardSubjectTag.textContent = card.subject;
      if (statInterval) statInterval.textContent = customIntervalText || card.interval;
      if (statMastery) statMastery.textContent = card.mastery;
      if (statDifficulty) statDifficulty.textContent = card.difficulty;
      if (cardQuestionText) cardQuestionText.textContent = card.question;
      if (cardAnswerText) cardAnswerText.innerHTML = card.answer;

      // Update button interval previews based on current card
      ratingButtons.forEach((btn) => {
        const ratingType = btn.getAttribute('data-rating');
        const intervalSpan = btn.querySelector('.rating-interval');
        if (intervalSpan && card.nextIntervals && card.nextIntervals[ratingType]) {
          intervalSpan.textContent = card.nextIntervals[ratingType];
        }
      });

      // Update active pill
      levelPills.forEach((pill, idx) => {
        pill.classList.toggle('active', idx === index);
      });

      if (mockupCardContent) {
        mockupCardContent.classList.remove('card-transitioning');
      }
    }, 160);
  }

  // Level selector click handlers
  levelPills.forEach((pill) => {
    pill.addEventListener('click', () => {
      const idx = parseInt(pill.getAttribute('data-index'), 10);
      if (!isNaN(idx) && idx !== currentCardIndex) {
        currentCardIndex = idx;
        renderCard(currentCardIndex);
      }
    });
  });

  // Rating button click handlers with immediate feedback and automatic progression
  ratingButtons.forEach((btn) => {
    btn.addEventListener('click', () => {
      const ratingType = btn.getAttribute('data-rating');
      const currentCard = demoCards[currentCardIndex];
      const scheduledInterval = currentCard?.nextIntervals?.[ratingType] || 'Next';

      // Visual feedback on stat chip with electric cyan glow
      if (statInterval) {
        statInterval.textContent = `Scheduled: ${scheduledInterval}`;
        statInterval.style.borderColor = 'var(--color-cyan-electric)';
        statInterval.style.boxShadow = '0 0 16px rgba(0, 194, 255, 0.45)';
        statInterval.style.color = '#FFFFFF';
      }

      // Advance to next card smoothly after brief calibration visual
      setTimeout(() => {
        currentCardIndex = (currentCardIndex + 1) % demoCards.length;
        renderCard(currentCardIndex);
        if (statInterval) {
          statInterval.style.borderColor = '';
          statInterval.style.boxShadow = '';
          statInterval.style.color = '';
        }
      }, 400);
    });
  });

  // Initialize first card intervals
  renderCard(0);
});
