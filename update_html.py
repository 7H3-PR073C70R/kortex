import re

with open('web_landing/index.html', 'r') as f:
    content = f.read()

# 1. Hero Section & Interactive Card Demo
hero_pattern = re.compile(r'<!-- Outcome-Driven Headline -->.*?<!-- FSRS-6 Rating Calibration Bar -->', re.DOTALL)
hero_replacement = """<!-- Outcome-Driven Headline -->
        <h1 class="hero-title reveal-on-scroll delay-1">
          Pass your hardest exams in half the time without losing sleep.
        </h1>

        <!-- Human Subtitle -->
        <p class="hero-subtitle reveal-on-scroll delay-2">
          Drop in messy PDFs, photos of your notes, or recorded lectures. Kortexify creates flashcards and practice tests automatically, showing them to you right before you forget them.
        </p>

        <!-- CTA Group -->
        <div class="hero-cta-group reveal-on-scroll delay-3">
          <a href="#workstation" class="btn-primary-cta">
            <span>Try For Free (No Signup Needed)</span>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
              <path d="M5 12h14M12 5l7 7-7 7"></path>
            </svg>
          </a>
          <a href="#pillars" class="btn-secondary-cta">
            <span>See How It Works</span>
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M19 9l-7 7-7-7"></path>
            </svg>
          </a>
        </div>

        <!-- Trust Badges Bar -->
        <div class="trust-badges-bar reveal-on-scroll delay-3">
          <div class="trust-badge-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"></path></svg>
            <span>Works 100% Offline</span>
          </div>
          <div class="trust-badge-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"></path></svg>
            <span>No Account Required</span>
          </div>
          <div class="trust-badge-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"></path></svg>
            <span>Trusted by over <strong class="social-proof-count">25,000</strong> students</span>
          </div>
        </div>

        <!-- Interactive Multi-Modal Workstation Preview -->
        <div class="workstation-wrapper reveal-on-scroll delay-4" id="workstation">
          
          <div class="workstation-tabs-bar">
            <div class="window-dots">
              <span class="dot-red"></span>
              <span class="dot-yellow"></span>
              <span class="dot-green"></span>
            </div>

            <div class="workstation-tabs" role="tablist" aria-label="Interactive Preview Modes">
              <button class="tab-btn active" data-tab="retain" role="tab" aria-selected="true">
                <span>📇 Flashcard Demo</span>
              </button>
            </div>
          </div>

          <div class="workstation-body">
            
            <!-- Tab 1: Retain (3D Flashcard & KaTeX) -->
            <div class="tab-panel active" id="panel-retain">
              <div class="card-scene">
                <div class="flashcard-3d" id="interactiveFlashcard" tabindex="0" role="button" aria-label="Interactive 3D Flashcard. Click or press space to flip.">
                  
                  <!-- Front of Card -->
                  <div class="card-face card-face-front">
                    <div class="card-meta-bar">
                      <span class="card-badge-topic" id="cardTopicBadge">Quick Question</span>
                      <span class="flip-hint-pill">Click Card or Press Space ↺</span>
                    </div>

                    <div class="card-content-area">
                      <p class="card-question-title" id="cardQuestionText">
                        Why do you forget things after reading them?
                      </p>
                    </div>

                    <div class="card-meta-bar" style="margin-bottom: 0;">
                      <span style="font-size: 0.78rem; color: var(--text-muted);">Active Recall • Front Prompt</span>
                      <button id="flipCardTrigger" type="button" class="tab-btn" style="padding: 4px 10px; font-size: 0.78rem; background: var(--color-primary-subtle); color: var(--color-primary);">
                        Reveal Solution →
                      </button>
                    </div>
                  </div>

                  <!-- Back of Card -->
                  <div class="card-face card-face-back">
                    <div class="card-meta-bar">
                      <span class="card-badge-topic" style="background: rgba(82, 121, 111, 0.15); color: var(--color-recall-easy);">Solution</span>
                      <span class="flip-hint-pill">Click to Flip Back ↺</span>
                    </div>

                    <div class="card-content-area">
                      <p style="font-size: 0.9rem; color: var(--text-secondary); margin-bottom: 8px;" id="cardAnswerText">
                        Because reading isn't testing. Your brain only keeps information when you practice bringing it back out. Kortexify builds that exact practice for you.
                      </p>
                    </div>

                    <div style="font-size: 0.78rem; color: var(--color-recall-easy); font-weight: 600;">
                      ✓ Verified
                    </div>
                  </div>

                </div>
              </div>

              <!-- FSRS-6 Rating Calibration Bar -->"""
content = hero_pattern.sub(hero_replacement, content)

# 2. Pillars Section
pillars_pattern = re.compile(r'<!-- Core Value Pillars.*?<!-- Key Differentiators', re.DOTALL)
pillars_replacement = """<!-- Core Value Pillars (3 Scannable Sections: Ingest, Retain, Test) -->
    <section class="section" id="pillars">
      <div class="container">
        
        <div class="section-header reveal-on-scroll">
          <span class="section-badge">The 3 Steps</span>
          <h2 class="section-title">Step-by-Step System</h2>
        </div>

        <div class="pillars-container">
          
          <!-- Pillar 1: Ingest -->
          <div class="pillar-row reveal-on-scroll delay-1">
            <div class="pillar-info">
              <div class="pillar-number">Step 1</div>
              <h3 class="pillar-title">Turn Messy Notes Into Quick Flashcards</h3>
              <p class="pillar-desc">
                Stop spending hours retyping your textbooks. Drop in your PDFs, photos of hand-written formulas, or voice notes. We instantly turn them into clean cards and clear study guides.
              </p>
            </div>
            <div class="pillar-visual">
              <div class="pillar-visual-card">
                <div style="font-size: 0.8rem; font-weight: 700; color: var(--color-primary); margin-bottom: 12px; letter-spacing: 0.04em;">INPUTS ACCEPTED</div>
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
                  <div class="diff-chip" style="padding: 10px; justify-content: center;">📑 PDFs & Slides</div>
                  <div class="diff-chip" style="padding: 10px; justify-content: center;">📸 Photo Notes</div>
                  <div class="diff-chip" style="padding: 10px; justify-content: center;">🎙️ Voice Lectures</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Pillar 2: Retain -->
          <div class="pillar-row reverse reveal-on-scroll delay-2">
            <div class="pillar-info">
              <div class="pillar-number">Step 2</div>
              <h3 class="pillar-title">Study Only What You Are About To Forget</h3>
              <p class="pillar-desc">
                Your brain naturally loses information over time. Our smart reminder system tracks your memory and tests you right before a topic slips away. You study less and remember far longer.
              </p>
            </div>
            <div class="pillar-visual">
              <div class="pillar-visual-card">
                <div style="font-size: 0.8rem; font-weight: 700; color: var(--color-recall-easy); margin-bottom: 12px; letter-spacing: 0.04em;">SMART REMINDERS</div>
                <div style="padding: 16px; background: var(--color-primary-tint); border-radius: var(--radius-md); border: 1px solid var(--border-subtle);">
                  <p style="font-size: 0.84rem; color: var(--text-secondary); line-height: 1.5;">Study exactly when you need to, saving hours of wasted time.</p>
                </div>
              </div>
            </div>
          </div>

          <!-- Pillar 3: Test -->
          <div class="pillar-row reveal-on-scroll delay-3">
            <div class="pillar-info">
              <div class="pillar-number">Step 3</div>
              <h3 class="pillar-title">Practice Under Real Exam Conditions</h3>
              <p class="pillar-desc">
                Reading over your notes makes you feel ready, but real tests feel different. Practice with real exam questions and timed tests for JAMB, WAEC, NECO, SAT, and university finals. If you miss a question, we automatically turn it into a quick review card so you never miss it twice.
              </p>
            </div>
            <div class="pillar-visual">
              <div class="pillar-visual-card">
                <div style="font-size: 0.8rem; font-weight: 700; color: var(--color-secondary); margin-bottom: 12px; letter-spacing: 0.04em;">EXAM PRACTICE</div>
                <div style="display: flex; gap: 8px; flex-wrap: wrap;">
                  <span class="diff-chip">JAMB</span>
                  <span class="diff-chip">WAEC / NECO</span>
                  <span class="diff-chip">SAT</span>
                  <span class="diff-chip">University Exams</span>
                </div>
              </div>
            </div>
          </div>

        </div>

      </div>
    </section>

    <!-- Key Differentiators -->"""
content = pillars_pattern.sub(pillars_replacement, content)

# 3. Differentiators
diff_pattern = re.compile(r'<!-- Key Differentiators.*?<!-- Comparison Matrix Table -->', re.DOTALL)
diff_replacement = """<!-- Key Differentiators -->
    <section class="section" id="differentiators" style="background: var(--bg-surface-elevated1);">
      <div class="container">
        
        <div class="section-header reveal-on-scroll">
          <span class="section-badge">Why Students Love Kortexify</span>
          <h2 class="section-title">Designed for everyone.</h2>
        </div>

        <div class="differentiators-grid">
          
          <!-- Differentiator 1 -->
          <div class="differentiator-card reveal-on-scroll delay-1">
            <div>
              <span class="diff-badge">🛡️ Works 100% Offline</span>
              <h3 class="diff-title">Study in lecture basements, on the bus, or anywhere without internet.</h3>
              <p class="diff-desc">
                Everything stays safely saved on your device without taking up space or tracking your personal data.
              </p>
            </div>
            <div class="diff-chips-row">
              <span class="diff-chip">No Internet Needed</span>
              <span class="diff-chip">Private & Secure</span>
            </div>
          </div>

          <!-- Differentiator 2 -->
          <div class="differentiator-card reveal-on-scroll delay-2">
            <div>
              <span class="diff-badge diff-badge-secondary">🧠 Designed For Every Type Of Brain</span>
              <h3 class="diff-title">Focus better, read easier.</h3>
              <p class="diff-desc">
                If reading dense pages gives you a headache, toggle on specialized reading fonts, high-contrast dark themes, or quick focus timers with one tap.
              </p>
            </div>
            <div class="diff-chips-row">
              <span class="diff-chip">Specialized Fonts</span>
              <span class="diff-chip">Focus Timers</span>
              <span class="diff-chip">Dark Themes</span>
            </div>
          </div>

        </div>

      </div>
    </section>

    <!-- Comparison Matrix Table -->"""
content = diff_pattern.sub(diff_replacement, content)

# 4. Comparison Table
comp_pattern = re.compile(r'<!-- Comparison Matrix Table -->.*?<!-- Founder\'s Note -->', re.DOTALL)
comp_replacement = """<!-- Comparison Matrix Table -->
    <section class="section" id="comparison">
      <div class="container">
        
        <div class="section-header reveal-on-scroll">
          <span class="section-badge">Comparison Table</span>
          <h2 class="section-title">The Kortexify Advantage</h2>
        </div>

        <div class="comparison-wrapper reveal-on-scroll delay-1">
          <table class="comparison-table">
            <thead>
              <tr>
                <th>What You Study With</th>
                <th>The Problem</th>
                <th class="col-highlight">The Kortexify Advantage</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Paper Notes</td>
                <td><span class="cross-red">✗ Easy to lose and hard to organize</span></td>
                <td class="col-highlight"><span class="check-green">✓ Everything stays organized in one pocket-sized place</span></td>
              </tr>
              <tr>
                <td>Basic AI Tools</td>
                <td><span class="cross-red">✗ Makes up wrong answers and needs internet</span></td>
                <td class="col-highlight"><span class="check-green">✓ Gives accurate answers and works completely offline</span></td>
              </tr>
              <tr>
                <td>Normal Flashcards</td>
                <td><span class="cross-red">✗ Shows you cards you already know</span></td>
                <td class="col-highlight"><span class="check-green">✓ Reminds you only when you are about to forget</span></td>
              </tr>
            </tbody>
          </table>
        </div>

      </div>
    </section>

    <!-- Founder's Note -->"""
content = comp_pattern.sub(comp_replacement, content)

# 5. Founder's Note & Remove Newsletter & FAQs & Final CTA
rest_pattern = re.compile(r'<!-- Founder\'s Note -->.*?</main>', re.DOTALL)
rest_replacement = """<!-- Founder's Note -->
    <section class="section" id="founder">
      <div class="container">
        <div class="founder-card reveal-on-scroll">
          <div class="founder-quote-icon">“</div>
          <p class="founder-text">
            We have all been there at 2:30 AM, staring at the exact same page for the fifth time, exhausted and stressed out. Cramming does not make you smarter; it just wears you out. We built Kortexify so you can walk into every exam feeling completely ready without sacrificing your sleep or your health.
          </p>
          <div class="founder-profile">
            <div class="founder-avatar">KX</div>
            <div>
              <div style="font-weight: 750; color: var(--text-primary);">A Quick Note From Our Team</div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Frequently Asked Questions -->
    <section class="section" id="faq">
      <div class="container">
        
        <div class="section-header reveal-on-scroll">
          <span class="section-badge">Common Questions</span>
          <h2 class="section-title">Frequently Asked Questions</h2>
        </div>

        <div class="faq-grid reveal-on-scroll delay-1">
          
          <div class="faq-item">
            <button class="faq-question" type="button" aria-expanded="false">
              <span>How does Kortexify save me study time?</span>
              <span class="faq-icon">+</span>
            </button>
            <div class="faq-answer">
              Most students waste hours re-reading stuff they already know. Kortexify figures out which topics are fading from your mind and shows you only those cards, cutting your study time down significantly.
            </div>
          </div>

          <div class="faq-item">
            <button class="faq-question" type="button" aria-expanded="false">
              <span>Can I upload my own class notes?</span>
              <span class="faq-icon">+</span>
            </button>
            <div class="faq-answer">
              Yes. You can upload lecture slides, PDF textbooks, audio files, or pictures of hand-written chalkboard notes.
            </div>
          </div>

          <div class="faq-item">
            <button class="faq-question" type="button" aria-expanded="false">
              <span>Does it work without Wi-Fi?</span>
              <span class="faq-icon">+</span>
            </button>
            <div class="faq-answer">
              Yes, completely. All your cards and practice tests work on your phone or laptop without using any internet data.
            </div>
          </div>

          <div class="faq-item">
            <button class="faq-question" type="button" aria-expanded="false">
              <span>What exams can I prepare for?</span>
              <span class="faq-icon">+</span>
            </button>
            <div class="faq-answer">
              You can practice with real questions for JAMB, WAEC, NECO, SAT, and university level courses.
            </div>
          </div>

        </div>

      </div>
    </section>

    <!-- Final Call to Action -->
    <section class="final-cta-section">
      <div class="container">
        <div class="section-header reveal-on-scroll" style="margin-bottom: 1.8rem;">
          <h2 class="section-title">Ready to ace your exams with total confidence?</h2>
          <p class="section-subtitle">
            Get started in under 30 seconds. No credit card or account creation needed.
          </p>
        </div>

        <div class="hero-cta-group reveal-on-scroll delay-1" style="margin-bottom: 0;">
          <a href="#workstation" class="btn-primary-cta">
            <span>Start Studying For Free</span>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
              <path d="M5 12h14M12 5l7 7-7 7"></path>
            </svg>
          </a>
        </div>
      </div>
    </section>

  </main>"""
content = rest_pattern.sub(rest_replacement, content)

with open('web_landing/index.html', 'w') as f:
    f.write(content)
