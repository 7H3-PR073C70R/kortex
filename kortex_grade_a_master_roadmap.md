# KORTEX GRADE-A MASTER EXECUTION ROADMAP
## Sequential Engineering & Product Architecture Blueprint

---

## Executive Overview & Architectural North Star

The objective of this roadmap is to systematically transform Kortex into a **Grade-A, production-grade educational technology system**. This document outlines an exhaustive, step-by-step master plan structured across **7 sequential phases**, with each phase divided into discrete, testable work units.

```
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│                               PHASED EXECUTION PIPELINE                                   │
├───────────────────────────────────────────────────────────────────────────────────────────┤
│  Phase 1: Core Data Integrity, Zero-Mock Audit & Unified Sync Engine                      │
│     │                                                                                     │
│     ▼                                                                                     │
│  Phase 2: Pillar 1 — Dashboard & Cognitive Telemetry (Readiness & Debt Triage)            │
│     │                                                                                     │
│     ▼                                                                                     │
│  Phase 3: Pillar 2 — Decks & Neural Recall Engine (FSRS-4.5 & Study Ergonomics)          │
│     │                                                                                     │
│     ▼                                                                                     │
│  Phase 4: Pillar 3 — Forum & Collaborative Learning (Socratic AI & Moderation)            │
│     │                                                                                     │
│     ▼                                                                                     │
│  Phase 5: Pillar 4 — Study Hub & Co-Presence (WebRTC Audio, Canvas & Synchronized Focus)  │
│     │                                                                                     │
│     ▼                                                                                     │
│  Phase 6: Pillar 5 — Profile, Security & Gamified Economy (Streaks & Pro Monetization)    │
│     │                                                                                     │
│     ▼                                                                                     │
│  Phase 7: Universal Production Polish, A11y & Automated Quality Gate                      │
└───────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Core Data Integrity, Zero-Mock Audit & Unified Sync Engine

> **Objective:** Establish an unwavering, offline-first foundation where no screen relies on hardcoded stubs, network disconnects never lose progress, and local SQLite (Drift) acts as the single source of truth.

### Milestone 1.1: Comprehensive Zero-Mock Hardening
- [ ] **1.1.1 Audit Fallback Generators:** Transition all fallback generators in `DashboardRemoteDataSourceImpl`, `DecksRemoteDataSourceImpl`, and `CommunityRemoteDataSourceImpl` to operate exclusively on authenticated user cache and seed data from bundled asset catalogs rather than synthetic inline strings.
- [ ] **1.1.2 Catalog Seed Migration:** Formalize default examination syllabi (WAEC, JAMB, NECO, SAT, IELTS) into compressed JSON asset bundles (`assets/seed/catalogs/`), loaded once on initial database provision via Drift migration strategy.
- [ ] **1.1.3 Strict Null-Safety & Contract Validation:** Ensure all model deserializers (`fromJson`) gracefully handle partial server payloads without throwing runtime unhandled exceptions or substituting fake statistics.

### Milestone 1.2: Unified Offline Sync Queue & Conflict Resolution
- [ ] **1.2.1 Bi-Directional Sync Queue:** Standardize `CardSyncQueue` into a generic `AppSyncEngine` supporting flashcard reviews, study room minutes, forum bookmarks, and quiz attempts.
- [ ] **1.2.2 Conflict Resolution Policy (Client-Wins for Progress):** Implement Last-Write-Wins (LWW) with client-dominant merge for active recall telemetry (highest retention score and highest repetition count always preserved).
- [ ] **1.2.3 Connection State & Visual Sync Beacon:** Expose a global network connectivity and sync status stream. Render an unobtrusive header indicator (`Synced`, `Syncing (X changes)`, `Offline mode`) across all 5 tab shells.

---

## Phase 2: Pillar 1 — Dashboard & Cognitive Telemetry

> **Objective:** Convert the Dashboard into a hyper-personalized command center that minimizes student decision fatigue, visualizes memory decay, and drives immediate daily study momentum.

```
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│                                   DASHBOARD BLUEPRINT                                     │
├───────────────────────────────────────────────────────────────────────────────────────────┤
│ [Header: Avatar + Level + Streak Fire + Shield Status]   [Sync Beacon: Emerald Synced]    │
│ ───────────────────────────────────────────────────────────────────────────────────────── │
│ [🔥 EXAM COUNTDOWN: WAEC 2026 • 42 Days Left • Readiness Index: 78% (On Track)]          │
│ ───────────────────────────────────────────────────────────────────────────────────────── │
│ [⚠️ BACKLOG TRIAGE: Calculus Derivatives • 38 Overdue Cards • "Launch 10-Card Sprint"]    │
│ ───────────────────────────────────────────────────────────────────────────────────────── │
│ [⚡ DAILY RECALL STATUS: 18 Cards Due Today • Next Best Action: Physics Magnetism]         │
│ ───────────────────────────────────────────────────────────────────────────────────────── │
│ [QUICK ACTIONS: Ingest Notes | CBT Past Questions | 1v1 Quiz Duel | Create Deck]          │
│ ───────────────────────────────────────────────────────────────────────────────────────── │
│ [CURATED COURSES CAROUSEL: MTH (84%) | PHY (62%) | CHM (45%) | BIO (70%)]                │
│ ───────────────────────────────────────────────────────────────────────────────────────── │
│ [POD PULSE: WAEC Sciences Pod • 5 Members Active • 240m Focused Today • +450 Karma]       │
│ ───────────────────────────────────────────────────────────────────────────────────────── │
│ [28-DAY COGNITIVE RETENTION HEATMAP & MASTERY BREAKDOWN]                                  │
└───────────────────────────────────────────────────────────────────────────────────────────┘
```

### Milestone 2.1: Cognitive Telemetry & Readiness Index
- [ ] **2.1.1 Dynamic CBT Readiness Algorithm:** Build an algorithmic score (0–100%) in `DashboardBloc` that computes weighted averages across:
  - Syllabus coverage % (enrolled courses).
  - FSRS card retention rate.
  - CBT past question mock scores.
  - Time remaining until scheduled exam date.
- [ ] **2.1.2 Adaptive Backlog Triage Engine:** Enhance `_StudyDebtTriageBanner` with intelligent card batching (5-card, 10-card, 15-card sprint modes) that filters specifically for cards with lowest retention stability.
- [ ] **2.1.3 Syllabot Cognitive Diagnostic Insights:** Replace rule-based streak text in `syllabotDailyInsight` with dynamic diagnostic feedback identifying the user's single weakest topic based on recent quiz errors.

### Milestone 2.2: Workstation Ergonomics & Responsive Polish
- [ ] **2.2.1 Desktop Workstation Refactor:** Optimize `_ExpandedDashboardLayout` (1024dp+) with responsive 2-column or 3-column split view (Telemetry + Review Queue + Live Pod).
- [ ] **2.2.2 Micro-Interactions & Motion Budgeting:** Apply staggered entrance curves (`Curves.easeOutQuint`), ensuring 60fps/120fps fluid frame budget with zero layout rebuild jank.
- [ ] **2.2.3 Course Module Quick Sheet:** Add interactive contextual sheet when tapping any course in `CuratedCourseCarousel` without forcing a full screen navigation transition.

---

## Phase 3: Pillar 2 — Decks & Neural Memory Architecture

> **Objective:** Deliver an uncompromising active-recall study experience matching FSRS-4.5 specifications, rich STEM rendering, and frictionless review gestures.

```
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│                                   DECKS ARCHITECTURE                                      │
├───────────────────────────────────────────────────────────────────────────────────────────┤
│ [Search & Tags Rail] -> [Subdeck Hierarchy Tree] -> [Deck Cards & Mastery Ring]           │
│                                                                                           │
│ STUDY SESSION WORKSPACE:                                                                  │
│  ├── Gesture Flip / 3D Perspective Animation                                              │
│  ├── MathJax / LaTeX Formula Rendering Engine                                             │
│  ├── Image Occlusion Mask & Tap-to-Reveal Surface                                         │
│  ├── Audio Pronunciation & Text-To-Speech Controller                                      │
│  ├── FSRS-4.5 Rating Action Bar ([Again <10m] [Hard 1d] [Good 3d] [Easy 7d])              │
│  ├── Contextual Socratic Hint Drawer (auto-triggers after repeated failures)              │
│  └── Desktop Accelerators: Key 1-4 for Ratings, Spacebar for Flip, Z for Undo             │
└───────────────────────────────────────────────────────────────────────────────────────────┘
```

### Milestone 3.1: FSRS-4.5 Engine Calibration & Retention Optimization
- [ ] **3.1.1 Parameter Tuning Interface:** Implement custom target retention configuration (default 90%) in user preferences, allowing students to optimize interval spacing for short-term cramming vs long-term retention.
- [ ] **3.1.2 Undo Card Review Action:** Add a 5-second snackbar and shake/hotkey undo mechanism during study sessions to revert accidental rating taps without corrupting FSRS stability metrics.
- [ ] **3.1.3 Thought Parking Lot Drawer:** Refine `ThoughtParkingLotSheet` allowing students to jot down fleeting intrusive thoughts during study sessions without breaking focus flow.

### Milestone 3.2: Rich Media Card Renderers
- [ ] **3.2.1 Image Occlusion Editor & Canvas:** Build in-app drawing and masking tool allowing users to upload textbook anatomical or technical diagrams, draw rectangular or polygon occlusion masks, and generate multiple child cards from a single asset.
- [ ] **3.2.2 Comprehensive LaTeX Formula Support:** Ensure multi-line equations, alignment tags (`\begin{aligned}`), chemical notation (`\ce{H2O}`), and mathematical symbols render instantaneously with zero layout shift.
- [ ] **3.2.3 Desktop Keyboard Ergonomics:** Wire physical hardware keys:
  - `Space` / `Enter`: Flip card.
  - `1`: Again, `2`: Hard, `3`: Good, `4`: Easy.
  - `E`: Edit card inline.
  - `H`: Reveal Socratic clue.

### Milestone 3.3: Deck Creation & Bulk Ingestion Pipeline
- [ ] **3.3.1 CSV / Anki (.apkg) Import Engine:** Enable direct local file parsing of Anki `.apkg` and CSV files into Kortex SQLite schema.
- [ ] **3.3.2 Syllabot Bulk Card Generator:** Support multi-page PDF document uploads, automatically generating 30–50 categorized flashcards tagged by syllabus subtopics with confidence scores.

---

## Phase 4: Pillar 3 — Forum & Collaborative Learning Subsystem

> **Objective:** Turn Kortex's community forum into a high-signal, curriculum-locked academic exchange free of social media clutter.

```
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│                                   COMMUNITY FORUM FLOW                                    │
├───────────────────────────────────────────────────────────────────────────────────────────┤
│ Track Selector -> Topic Filter Pills -> Full-Text Keystroke Debounced Search             │
│                                                                                           │
│ THREAD ARCHITECTURE:                                                                      │
│  ├── Author Profile & Academic Rank Tag (e.g., Neural Scholar III)                        │
│  ├── Syllabus Anchor Pill (e.g., WAEC • Mathematics • Quadratic Equations)                │
│  ├── Verified Solution Badge & Instructor Endorsement Flag                                │
│  ├── Socratic AI Hint Drawer (Tiers 1, 2, 3: Clue, Method, Formula)                       │
│  ├── Interactive Mathematical LaTeX Rendering                                             │
│  ├── Optimistic Upvoting / Karma Propagation                                              │
│  └── Content Flagging & Automatic Moderation Workflow                                     │
└───────────────────────────────────────────────────────────────────────────────────────────┘
```

### Milestone 4.1: High-Signal Academic Search & Curation
- [ ] **4.1.1 Keystroke-Debounced Keyset Pagination:** Implement SQLite full-text search (FTS5) for local cache combined with Supabase Keyset pagination (`created_at`, `id`) to ensure sub-50ms query speeds.
- [ ] **4.1.2 Syllabus Subtopic Filtering:** Allow filtering by exact official exam syllabus codes (e.g., `WAEC-MTH-ALG-04`).
- [ ] **4.1.3 Verified Solution Pinning:** Enable thread creators and verified tutors to pin the definitive solution, which highlights in emerald with step-by-step breakdown.

### Milestone 4.2: Socratic AI & Community Safety
- [ ] **4.2.1 Socratic Hint Progressive Disclosure:** Expand `ForumSocraticHintService` to provide 3 expandable hint accordions:
  - *Level 1: Core Concept Clue*
  - *Level 2: Mathematical / Methodological Direction*
  - *Level 3: Formula & Pitfall Warning*
- [ ] **4.2.2 Automated Content Moderation:** Integrate real-time content heuristics to filter profanity, contact information, and off-topic chatter prior to Supabase submission.
- [ ] **4.2.3 Push Notification Dispatch:** Connect post subscription to FCM topic listeners (`forum_post_{id}`) so replies notify subscribed peers instantly.

---

## Phase 5: Pillar 4 — Study Hub & Co-Presence Engine

> **Objective:** Build an immersive deep-work environment with zero audio latency, synchronized group Pomodoros, and interactive collaborative whiteboards.

```
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│                                  STUDY HUB & ROOM SYSTEM                                  │
├───────────────────────────────────────────────────────────────────────────────────────────┤
│ Tab 1: Live Focus Rooms & Study Circles      │      Tab 2: Peer Deck Marketplace          │
│                                                                                           │
│ LIVE STUDY ROOM ECOSYSTEM:                                                                │
│  ├── Ephemeral Presence Broadcast (Zero-DB Heartbeat via Realtime Channels)               │
│  ├── LiveKit Low-Latency WebRTC Voice (Push-To-Talk, Mute, Noise Suppression)             │
│  ├── Synchronized Group Pomodoro (Host/Room sync with break transitions)                  │
│  ├── Multi-user Real-time Whiteboard Canvas (Pen, Eraser, Shapes, Pan/Zoom)               │
│  ├── In-Room Deck Study Split-View (Study private/shared flashcards in session)           │
│  ├── Floating Haptic Emojis & Hand-Raise Queue                                            │
│  └── Post-Session Focus Summary (Duration, Cards Reviewed, XP Karma Bonus)               │
└───────────────────────────────────────────────────────────────────────────────────────────┘
```

### Milestone 5.1: Ephemeral Presence & LiveKit WebRTC Audio
- [ ] **5.1.1 Presence State Machine:** Harden `EphemeralPresenceClient` to handle transient network drops with 15-second grace periods before marking participants offline.
- [ ] **5.1.2 WebRTC Audio Resilience:** Implement automatic fallback to silent focus mode if microphone hardware permissions are denied or low-bandwidth conditions occur.
- [ ] **5.1.3 Spatial Audio & Ambient Sound Mix:** Allow students to mix ambient audio (Lo-Fi beats, Rain, Library sounds) independently of peer voice volume.

### Milestone 5.2: Synchronized Whiteboard & Study Workspace
- [ ] **5.2.1 Smooth Vector Whiteboard Canvas:** Upgrade `WhiteboardCanvasWidget` with Catmull-Rom spline stroke smoothing, multi-touch pinch-to-zoom, and SVG/PNG export.
- [ ] **5.2.2 In-Room Shared Deck Synchronization:** Allow the room host to launch a synchronized card sprint where all room members review the same flashcard simultaneously with countdown timers.
- [ ] **5.2.3 Focus Session XP Attribution:** Calculate focused minutes upon room departure, credit user telemetry via `UserActivityService.recordStudySession`, and display celebratory milestone summary.

---

## Phase 6: Pillar 5 — Profile, Security & Gamified Economy

> **Objective:** Deepen student retention through verified identity, tangible academic ranks, streak shield economics, and frictionless Pro upgrades.

```
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│                                   PROFILE & ACCOUNT SYSTEM                                │
├───────────────────────────────────────────────────────────────────────────────────────────┤
│ [Scholar Hub Card: Avatar, Level, Streak Fire, Retention %, Shield Status]                │
│                                                                                           │
│ SETTINGS MODULES:                                                                         │
│  ├── Academic Track & Daily Target (WAEC/JAMB/SAT, 10-50 cards/day)                       │
│  ├── Syllabot AI & Neural Engine (Tutor Style, Speech Rate, Offline Weights)              │
│  ├── Leaderboard & Leagues (Cohort XP rankings, Weekly Promotion/Relegation)              │
│  ├── Account & Security (Password, TOTP 2FA Authenticator Setup, Session Manager)         │
│  ├── Appearance & Sounds (Theme, Sensory Haptics, Volume, Sound FX)                       │
│  ├── Interactive Guided Tour Replay (Step 1-9 Walkthrough)                                │
│  └── Membership & Pro Paywall (RevenueCat / Stripe subscription tiering)                  │
└───────────────────────────────────────────────────────────────────────────────────────────┘
```

### Milestone 6.1: Scholar Identity & Streak Shield Economy
- [ ] **6.1.1 Streak Freeze Purchasing & Safety:** Ensure `UserActivityService` deducts 200 XP for streak freeze purchases with immediate balance updates and local persistence.
- [ ] **6.1.2 Level Progression Scaling:** Implement non-linear level curve ($XP_{required} = 100 \times \text{level}^{1.4}$) with unlockable cosmetic avatar frames.
- [ ] **6.1.3 Avatar Customization & Camera Crop:** Support custom photo upload with circular aspect ratio cropping, image compression (<100KB), and Supabase storage upload.

### Milestone 6.2: Security, 2FA & Account Protection
- [ ] **6.2.1 Authenticator TOTP Setup:** Build standard RFC 6238 TOTP QR code generator and verification screen in `TwoFactorSetupPage`.
- [ ] **6.2.2 Biometric Lock (FaceID / Fingerprint):** Allow students to require biometric unlock to open the app or access exams.
- [ ] **6.2.3 Active Session Management:** Display list of active device sessions with remote revoke capabilities.

---

## Phase 7: Universal System Standards & Grade-A Polish

> **Objective:** Ensure the entire application meets the highest software engineering standards for accessibility, frame rate stability, and test coverage.

### Milestone 7.1: Accessibility (a11y) & Visual Design Excellence
- [ ] **7.1.1 Semantic Labels & Screen Readers:** Audit all custom touchable elements, icon buttons, and canvas controllers with descriptive `Semantics` tags.
- [ ] **7.1.2 WCAG 2.1 AA Contrast Compliance:** Validate color contrast ratios (minimum 4.5:1 for body text, 3:1 for large headings) across both dark and light themes.
- [ ] **7.1.3 Dynamic Type Support:** Ensure layouts do not truncate or overlap when system accessibility font scaling is set up to 150%.

### Milestone 7.2: Performance Budgeting (< 16ms Frame Time)
- [ ] **7.2.1 RepaintBoundary Isolation:** Wrap complex animating widgets (Heatmaps, Progress Rings, Confetti, Skeletons) in `RepaintBoundary` to prevent unnecessary root-level raster repaints.
- [ ] **7.2.2 Image & Memory Caching:** Enforce memory bounds (`cacheWidth`, `cacheHeight`) on avatar and question image decodes to guarantee low RAM footprint.

### Milestone 7.3: Automated Test Matrix
- [ ] **7.3.1 Domain & Logic Unit Tests:** 100% test coverage on `FsrsScheduler`, `EbbinghausDecayCalculator`, `UserActivityService`, and `DeckTitleResolver`.
- [ ] **7.3.2 BLoC & Cubit State Verification:** Comprehensive test cases for `DashboardBloc`, `DecksBloc`, `CommunityHubBloc`, and `LiveRoomCubit`.
- [ ] **7.3.3 End-to-End Golden Integration Tests:** Screenshot golden validation across Compact (Mobile), Medium (Tablet), and Expanded (Desktop 1080p).

---

## Execution Protocol & Progress Tracking Matrix

| Phase | Core Domain | Focus Key Deliverables | Status |
| :---: | :--- | :--- | :---: |
| **1** | **Data Integrity** | Unified sync engine, offline seed catalog, zero-mock cleanup | `READY TO START` |
| **2** | **Dashboard** | CBT readiness index, backlog debt triage, cognitive diagnostics | `PLANNED` |
| **3** | **Decks** | FSRS-4.5 parameter tuning, undo review, rich media renderers | `PLANNED` |
| **4** | **Forum** | Keyset pagination, syllabus filtering, Socratic hint tiers | `PLANNED` |
| **5** | **Study Hub** | Presence heartbeat, WebRTC audio, shared synchronized canvas | `PLANNED` |
| **6** | **Profile & Security** | Streak economy, TOTP 2FA setup, biometric app lock | `PLANNED` |
| **7** | **Grade-A Polish** | WCAG AA contrast, frame budgeting, 100% core test suite | `PLANNED` |
