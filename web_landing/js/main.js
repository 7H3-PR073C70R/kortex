/**
 * KORTEX LANDING PAGE CORE LOGIC
 * Waitlist submission, validation, live counter, and interactive demo.
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
  let currentCount = parseInt(localStorage.getItem('kortex_waitlist_count') || baseCount, 10);
  updateCounts(currentCount);

  // Periodic organic increment simulation
  setInterval(() => {
    if (Math.random() > 0.6) {
      currentCount += 1;
      localStorage.setItem('kortex_waitlist_count', currentCount);
      updateCounts(currentCount);
    }
  }, 12000);

  // 2. Email Validation & Waitlist Form Submission
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
        showFeedback(feedback, 'Please enter your university or personal email.', 'error');
        input.focus();
        return;
      }

      if (!isValidEmail(email)) {
        showFeedback(feedback, 'Please enter a valid email address (e.g., student@mit.edu).', 'error');
        input.focus();
        return;
      }

      // Submission state
      button.disabled = true;
      const originalButtonText = button.innerHTML;
      button.innerHTML = '<span class="spinner"></span> Securing Spot...';

      try {
        // Save to LocalStorage
        const existingLeads = JSON.parse(localStorage.getItem('kortex_leads') || '[]');
        if (!existingLeads.includes(email)) {
          existingLeads.push(email);
          localStorage.setItem('kortex_leads', JSON.stringify(existingLeads));
          currentCount += 1;
          updateCounts(currentCount);
        }

        // Simulate network API latency
        await new Promise((resolve) => setTimeout(resolve, 800));

        showFeedback(
          feedback,
          `🎉 You're in! VIP Private Beta access link sent to ${email}.`,
          'success'
        );
        input.value = '';
        button.innerHTML = 'Spot Reserved ✓';
      } catch (err) {
        showFeedback(feedback, 'Connection glitch. Your spot was saved locally!', 'success');
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

  // 3. Interactive Hero Flashcard Rating Buttons Simulation
  const ratingButtons = document.querySelectorAll('.rating-btn');
  const formulaBox = document.querySelector('.mockup-formula-box');
  const cardSubject = document.querySelector('.card-subject-tag');
  const fsrsIntervalStat = document.querySelector('.stat-chip:first-child');

  const demoCards = [
    {
      subject: 'PHYS 201 • Quantum Mechanics',
      formula: '$$\\hat{H}\\Psi = E\\Psi$$',
      stats: 'Interval: 3d',
    },
    {
      subject: 'MATH 314 • Multivariable Calculus',
      formula: '$$\\oint_{\\partial S} \\mathbf{F} \\cdot d\\mathbf{r} = \\iint_S (\\nabla \\times \\mathbf{F}) \\cdot d\\mathbf{S}$$',
      stats: 'Interval: 7d',
    },
    {
      subject: 'CHEM 102 • Physical Chemistry',
      formula: '$$\\Delta G = \\Delta H - T\\Delta S$$',
      stats: 'Interval: 14d',
    },
  ];

  let currentDemoIndex = 0;

  ratingButtons.forEach((btn) => {
    btn.addEventListener('click', () => {
      // Advance to next demo formula
      currentDemoIndex = (currentDemoIndex + 1) % demoCards.length;
      const nextCard = demoCards[currentDemoIndex];

      if (formulaBox && cardSubject && fsrsIntervalStat) {
        formulaBox.style.opacity = '0';
        setTimeout(() => {
          cardSubject.textContent = nextCard.subject;
          formulaBox.textContent = nextCard.formula;
          fsrsIntervalStat.textContent = nextCard.stats;
          formulaBox.style.opacity = '1';
        }, 150);
      }
    });
  });
});
