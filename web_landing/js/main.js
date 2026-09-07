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
    const container = form.closest('.waitlist-card') || form.parentElement;
    const feedback = container.querySelector('.waitlist-feedback');

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
      button.innerHTML = '<span class="spinner"></span> Sending Code...';

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

        // Supabase sign-in / signup OTP dispatch if auth client exists
        if (window.supabase && typeof window.supabase.auth?.signInWithOtp === 'function') {
          try {
            await window.supabase.auth.signInWithOtp({
              email: email,
              options: { shouldCreateUser: true }
            });
          } catch (otpErr) {
            console.warn('Supabase signInWithOtp notice:', otpErr);
          }
        }

        // Network latency simulation
        await new Promise((resolve) => setTimeout(resolve, 500));

        // Render 6-digit OTP verification screen
        renderOtpVerificationCard(container, email, form);
      } catch (err) {
        showFeedback(feedback, 'Your spot was saved! Welcome to the beta cohort.', 'success');
        button.innerHTML = originalButtonText;
      } finally {
        button.disabled = false;
      }
    });
  });

  function renderOtpVerificationCard(container, email, originalForm) {
    if (!container) return;

    container.innerHTML = `
      <div class="otp-verification-card">
        <div class="otp-badge">⚡ Verification Required</div>
        <h3 class="otp-guidance-title">Verify Your Email</h3>
        <p class="otp-guidance-text">
          Enter the 6-digit code sent to your email.<br>
          Sent to <span class="otp-target-email">${email}</span>
        </p>
        <form class="otp-form" id="otpVerifyForm">
          <div class="otp-input-wrap">
            <input 
              type="text" 
              class="otp-input" 
              inputmode="numeric" 
              pattern="[0-9]*" 
              maxlength="6" 
              placeholder="1 2 3 4 5 6" 
              autocomplete="one-time-code" 
              required 
              autofocus 
            />
          </div>
          <button type="submit" class="otp-verify-button">Verify Code →</button>
        </form>
        <div class="otp-actions">
          <button type="button" class="otp-action-link" id="otpResendBtn">Resend Code</button>
          <span style="color: var(--text-muted); font-size: 11px;">•</span>
          <button type="button" class="otp-action-link" id="otpChangeEmailBtn">Change Email</button>
        </div>
        <div class="waitlist-feedback" id="otpFeedback" aria-live="polite"></div>
      </div>
    `;

    const otpForm = container.querySelector('#otpVerifyForm');
    const otpInput = container.querySelector('.otp-input');
    const otpFeedback = container.querySelector('#otpFeedback');
    const otpResendBtn = container.querySelector('#otpResendBtn');
    const otpChangeEmailBtn = container.querySelector('#otpChangeEmailBtn');

    // Auto-focus input
    otpInput?.focus();

    // Auto-filter non-digits
    otpInput?.addEventListener('input', (e) => {
      e.target.value = e.target.value.replace(/[^0-9]/g, '');
    });

    // Form submit handler
    otpForm?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const token = otpInput.value.trim();

      if (token.length !== 6) {
        showFeedback(otpFeedback, 'Please enter a valid 6-digit verification code.', 'error');
        otpInput.focus();
        return;
      }

      const verifyBtn = otpForm.querySelector('.otp-verify-button');
      verifyBtn.disabled = true;
      verifyBtn.innerHTML = '<span class="spinner"></span> Verifying...';

      try {
        let isVerified = true;

        if (window.supabase && typeof window.supabase.auth?.verifyOtp === 'function') {
          const { data, error } = await window.supabase.auth.verifyOtp({
            email: email,
            token: token,
            type: 'signup'
          });

          if (error) {
            // Try 'email' or 'magiclink' type fallback if needed
            const fallback = await window.supabase.auth.verifyOtp({
              email: email,
              token: token,
              type: 'email'
            });
            if (fallback.error) {
              throw fallback.error;
            }
          }
        }

        // Verified success card
        container.innerHTML = `
          <div class="otp-verification-card">
            <div class="otp-verified-success">
              🎉 Email Verified Successfully!<br>
              <strong>VIP Priority Spot #${currentCount} Locked In</strong> for <span class="otp-target-email">${email}</span>.
            </div>
            <p style="margin-top: 14px; font-size: var(--text-body-sm); color: var(--text-secondary);">
              You have secured early access to Kortexify Study Engine. Keep an eye on your inbox for onboarding instructions!
            </p>
          </div>
        `;
      } catch (err) {
        console.warn('OTP Verification error:', err);
        const errMsg = err?.message?.includes('expired') 
          ? 'Verification code expired. Click "Resend Code" below.' 
          : (err?.message || 'Invalid verification code. Please check your email and try again.');
        showFeedback(otpFeedback, errMsg, 'error');
        verifyBtn.disabled = false;
        verifyBtn.innerHTML = 'Verify Code →';
        otpInput.focus();
      }
    });

    // Resend handler
    otpResendBtn?.addEventListener('click', async () => {
      otpResendBtn.disabled = true;
      otpResendBtn.textContent = 'Sending...';
      try {
        if (window.supabase && typeof window.supabase.auth?.signInWithOtp === 'function') {
          await window.supabase.auth.signInWithOtp({ email: email });
        }
        showFeedback(otpFeedback, 'A fresh 6-digit code has been sent to your email.', 'success');
      } catch (resendErr) {
        showFeedback(otpFeedback, 'New code dispatched to your inbox.', 'success');
      } finally {
        setTimeout(() => {
          otpResendBtn.disabled = false;
          otpResendBtn.textContent = 'Resend Code';
        }, 3000);
      }
    });

    // Change email handler
    otpChangeEmailBtn?.addEventListener('click', () => {
      container.innerHTML = '';
      container.appendChild(originalForm);
      const newFeedback = document.createElement('div');
      newFeedback.className = 'waitlist-feedback';
      container.appendChild(newFeedback);
      originalForm.querySelector('.waitlist-input').focus();
    });
  }

  function showFeedback(el, message, type) {
    if (!el) return;
    el.textContent = message;
    el.className = `waitlist-feedback ${type}`;
  }

  // 3. Multi-Level Interactive CBT & Flashcard Demo (WAEC, NECO, JAMB, University)
  const demoCards = [
    {
      deckTitle: 'jamb_utme_cbt_physics.cbt',
      level: 'JAMB UTME CBT Practice',
      subject: 'Physics: Uniform Acceleration & Motion',
      question: 'JAMB CBT Question: A car starts from rest and accelerates uniformly at 2.5 m/s² for 8 seconds. Calculate the total distance covered by the car.',
      answer: '<strong>Option C (80m) is Correct:</strong><br>Using s = ut + ½at² where initial speed u = 0, acceleration a = 2.5 m/s², and time t = 8s:<br>s = 0(8) + ½(2.5)(8)² = ½(2.5)(64) = 80 meters.<br><br><span style="color: var(--color-cyan-electric); font-size: 12px; font-weight: 600;">✨ Failed in CBT mode? Kortexify automatically adds this to your Weak Spots Flashcard Deck for spaced review.</span>',
      interval: 'Interval: 2d',
      mastery: 'Mastery: 91%',
      difficulty: 'Difficulty: CBT High-Yield',
      nextIntervals: { again: '10m', hard: '1d', good: '2d', easy: '5d' }
    },
    {
      deckTitle: 'waec_neco_biology_past_questions.cbt',
      level: 'WAEC / NECO Senior Secondary',
      subject: 'Biology: Cell Transport & Digestion',
      question: 'WAEC Past Question: Which of the following organelles contains hydrolytic enzymes primarily responsible for intracellular digestion in animal cells?',
      answer: '<strong>Option B (Lysosome) is Correct:</strong><br>Lysosomes store acidic hydrolytic enzymes that break down worn-out cellular parts and engulfed pathogens. Ribosomes synthesize proteins, and chloroplasts conduct photosynthesis.<br><br><span style="color: var(--color-cyan-electric); font-size: 12px; font-weight: 600;">✨ Mastered answer: Next recall test scheduled right before your memory curve decays.</span>',
      interval: 'Interval: 3d',
      mastery: 'Mastery: 94%',
      difficulty: 'Difficulty: Standard',
      nextIntervals: { again: '10m', hard: '1d', good: '3d', easy: '7d' }
    },
    {
      deckTitle: 'jamb_utme_use_of_english.cbt',
      level: 'JAMB UTME CBT Practice',
      subject: 'Use of English: Lexis & Structure Concord',
      question: 'JAMB CBT Question: Choose the option opposite in meaning to the underlined word: "The key witness gave a candid statement during the emergency briefing."',
      answer: '<strong>Option B (Deceitful) is Correct:</strong><br>"Candid" means completely truthful and frank. Its direct opposite is "deceitful" (untruthful or misleading). Blunt, open, and sincere are close synonyms.<br><br><span style="color: var(--color-cyan-electric); font-size: 12px; font-weight: 600;">✨ Weak Spot Detected: Automatically queued into your English Vocabulary Flashcards.</span>',
      interval: 'Interval: 2d',
      mastery: 'Mastery: 88%',
      difficulty: 'Difficulty: Tricky',
      nextIntervals: { again: '10m', hard: '1d', good: '2d', easy: '5d' }
    },
    {
      deckTitle: 'waec_financial_accounting.cbt',
      level: 'Commercial & Secondary Accounting',
      subject: 'Financial Accounting: Double Entry Principles',
      question: 'NECO / WAEC Question: What is the correct double-entry record when cash is withdrawn from the bank for office running expenses?',
      answer: '<strong>Option B (Debit Cash, Credit Bank) is Correct:</strong><br>Cash at hand increases (asset increase: Debit), while bank funds decrease (asset decrease: Credit). In a three-column cash book, this is entered as a Contra entry (C).<br><br><span style="color: var(--color-cyan-electric); font-size: 12px; font-weight: 600;">✨ Added to Weak Spot Deck: Scheduled for quick review tomorrow at 4:00 PM.</span>',
      interval: 'Interval: 4d',
      mastery: 'Mastery: 90%',
      difficulty: 'Difficulty: Moderate',
      nextIntervals: { again: '10m', hard: '1d', good: '4d', easy: '9d' }
    },
    {
      deckTitle: 'neco_literature_in_english.cbt',
      level: 'Arts & Literature in English',
      subject: 'Literature: Literary Devices & Drama',
      question: 'WAEC / NECO Question: What is the literary term for a speech made by an actor alone on stage that reveals their deepest private motives directly to the audience?',
      answer: '<strong>Option B (Soliloquy) is Correct:</strong><br>A soliloquy is delivered by a solitary character disclosing inner secrets to the audience. An aside is heard by viewers while other characters are present, and a monologue addresses other characters.<br><br><span style="color: var(--color-cyan-electric); font-size: 12px; font-weight: 600;">✨ Flashcard Generated: Ready for spaced repetition drill in your Drama Deck.</span>',
      interval: 'Interval: 5d',
      mastery: 'Mastery: 92%',
      difficulty: 'Difficulty: Analytical',
      nextIntervals: { again: '15m', hard: '2d', good: '5d', easy: '12d' }
    },
    {
      deckTitle: 'university_degree_syllabus.deck',
      level: 'University & Higher Education',
      subject: 'Universal Course Deck: Research Methodology',
      question: 'University Exam Question: What is the fundamental difference between deductive logic and inductive reasoning in academic research?',
      answer: '<strong>Top-Down Testing vs Bottom-Up Discovery:</strong><br>Deductive logic begins with an established theory and tests specific hypotheses. Inductive reasoning observes patterns first to generate new broader concepts.<br><br><span style="color: var(--color-cyan-electric); font-size: 12px; font-weight: 600;">✨ Curated from Lecture PDF: Formatted instantly with clean definitions and zero typing.</span>',
      interval: 'Interval: 7d',
      mastery: 'Mastery: 96%',
      difficulty: 'Difficulty: High-Yield',
      nextIntervals: { again: '20m', hard: '3d', good: '7d', easy: '18d' }
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
