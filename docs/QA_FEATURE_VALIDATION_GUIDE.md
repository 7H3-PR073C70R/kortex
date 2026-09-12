# Kortex — Comprehensive QA Master Validation Guide & End-to-End Test Specification

> **Document Version:** 2.2.0  
> **Author:** Senior QA Lead & Quality Engineering Specialist  
> **Target Audience:** QA Engineers, Test Automation Engineers, Release Managers, Product Leads  
> **Platform Scope:** Flutter (iOS, Android, Web, macOS)  
> **Reference Document:** [FEATURES.md](file:///Users/protector/Documents/projects/kortex/docs/FEATURES.md)  
> **Test Methodologies:** Manual Exploratory, Black-Box Functional, Boundary Value Analysis, Negative/Chaos Testing, WCAG 2.1 AA Accessibility Auditing, BLoC State Validation, and Offline-First Drift Synchronization Testing.

---

## Table of Contents

1. [QA Strategy, Execution Standards & Severity Taxonomy](#1-qa-strategy-execution-standards--severity-taxonomy)
2. [Module 1: Onboarding, Calibration & Academic Track Configuration](#module-1-onboarding-calibration--academic-track-configuration) (ONB-01 – ONB-12)
3. [Module 2: Dashboard & Smart Study Command Center](#module-2-dashboard--smart-study-command-center) (DSH-01 – DSH-10)
4. [Module 3: Flashcard Studio & Spaced Repetition (FSRS-6)](#module-3-flashcard-studio--spaced-repetition-fsrs-6) (FSR-01 – FSR-15)
5. [Module 4: Document Ingestion, OCR & Multimodal Synthesis](#module-4-document-ingestion-ocr--multimodal-synthesis) (ING-01 – ING-12)
6. [Module 5: Syllabot AI: Socratic Learning & Multimodal Assistant](#module-5-syllabot-ai-socratic-learning--multimodal-assistant) (SYL-01 – SYL-14)
7. [Module 6: Gamified Quiz Arena & CBT Practice Engine](#module-6-gamified-quiz-arena--cbt-practice-engine) (QZ-01 – QZ-16)
8. [Module 7: Community Hub, Body Doubling & Live Study Rooms](#module-7-community-hub-body-doubling--live-study-rooms) (COM-01 – COM-18)
9. [Module 8: Exam Timetable & Cram Workload Planner](#module-8-exam-timetable--cram-workload-planner) (PLN-01 – PLN-08)
10. [Module 9: ADHD & Neurodivergent Accessibility Suite](#module-9-adhd--neurodivergent-accessibility-suite) (ACC-01 – ACC-10)
11. [Module 10: Profile, Security & Two-Factor Authentication](#module-10-profile-security--two-factor-authentication) (SEC-01 – SEC-09)
12. [Module 11: Monetization, RevenueCat & Subscription Guards](#module-11-monetization-revenuecat--subscription-guards) (MON-01 – MON-06)
13. [Module 12: Offline-First Architecture & Core Infrastructure](#module-12-offline-first-architecture--core-infrastructure) (INF-01 – INF-11)
14. [Automated Test Suite Execution Matrix](#14-automated-test-suite-execution-matrix)

---

## 1. QA Strategy, Execution Standards & Severity Taxonomy

### Defect Severity Definitions
- **Blocker (S1):** Application crash, data loss, FSRS calculation corruption, unhandled exception in core study loop, or security bypass.
- **Critical (S2):** Core feature non-functional (e.g., cannot flip card, OCR fails without error message, offline sync queue drops logs).
- **Major (S3):** Feature works partially, visual overflow, broken animation fallback, or latency $>1000\text{ms}$ on local operations.
- **Minor (S4):** Typos, minor layout misalignment, subtle color contrast variance, non-blocking UI glitch.

### Standard Test Environment Matrix
| Layer | Specifications |
| :--- | :--- |
| **Android Physical/Emulators** | Android 10 (API 29) to Android 15 (API 35), Low-end (2GB RAM) & High-end (8GB RAM) |
| **iOS Physical/Simulators** | iOS 16.0 to iOS 18.x (iPhone SE 3rd Gen, iPhone 15 Pro, iPad Air) |
| **Network Conditions** | 5G Full Speed, 3G/2G Flaky Simulation (100kbps, 400ms latency), 100% Airplane Mode |
| **Accessibility Tools** | TalkBack (Android), VoiceOver (iOS), Color Inversion, Display Font Scaling ($1.0\times$ to $2.0\times$) |

---

## Module 1: Onboarding, Calibration & Academic Track Configuration

### ONB-01: Splash & Dynamic Route Resolver
- **Preconditions:** App installed fresh or with an existing authenticated/unauthenticated session token in secure storage.
- **Step-by-Step Test Steps:**
  1. Cold launch the application on device/emulator.
  2. Measure time from app launch icon tap to splash screen resolution.
  3. Case A (Fresh Install / No Token): Verify navigation redirects to `/onboarding`.
  4. Case B (Valid Token & Onboarding Completed): Verify navigation redirects to `/dashboard`.
  5. Case C (Valid Token & Biometric Lock Enabled): Verify biometric prompt appears before entering `/dashboard`.
- **Expected Results:**
  - Route resolves deterministically in $<150\text{ms}$.
  - No blank/white screen or jank during initial route determination.
- **Edge Cases & Failure Handling:**
  - Corrupt or expired token in secure storage: System clears token gracefully and routes to Onboarding/Login without crashing.
- **Automated Verification:** `flutter test test/features/onboarding/presentation/splash_page_test.dart`

---

### ONB-02: Rocket Launch Animation Overlay
- **Preconditions:** User reaches final step of onboarding calibration.
- **Step-by-Step Test Steps:**
  1. Complete all required calibration steps and tap **"Launch My Study Journey"**.
  2. Observe the full-screen rocket animation trajectory, particle trail, and haptic feedback.
  3. Attempt to tap background UI during launch.
- **Expected Results:**
  - Rocket ascends smoothly at 60 FPS.
  - Haptic feedback fires at liftoff.
  - Background interaction is safely blocked during animation.
  - Automatically transitions to Dashboard upon animation completion.
- **Edge Cases:**
  - System Reduced Motion enabled: Rocket animation is skipped or replaced with a gentle cross-fade transition.
- **Automated Verification:** `flutter test test/features/onboarding/presentation/widgets/rocket_launch_overlay_test.dart`

---

### ONB-03: Value Proposition Tour Carousel
- **Preconditions:** Fresh launch in uncalibrated state.
- **Step-by-Step Test Steps:**
  1. Swipe left across the 3 carousel slides (Active Recall, Syllabot AI, Live Study Rooms).
  2. Observe animated page indicator dots smoothly morphing and highlighting current slide.
  3. Tap the **"Skip"** button on slide 1.
  4. Tap the **"Next"** button sequentially on slides 1, 2, and 3.
- **Expected Results:**
  - Swiping and button clicks advance slides with no frame drops.
  - Tapping **"Skip"** immediately jumps to Diagnostic Step.
  - Semantics labels announce page 1 of 3, 2 of 3, etc.
- **Edge Cases:**
  - Rapid double-swiping: Does not cause index out-of-bounds.
- **Automated Verification:** `flutter test test/features/onboarding/presentation/onboarding_carousel_test.dart`

---

### ONB-04: Academic Focus Diagnostic Step
- **Preconditions:** Onboarding slide tour completed or skipped.
- **Step-by-Step Test Steps:**
  1. View the two primary focus tracks: **"High School / College Prep"** and **"Higher Education / University"**.
  2. Tap **"High School"** and tap **"Continue"**.
  3. Navigate back and switch selection to **"Higher Education"** and tap **"Continue"**.
- **Expected Results:**
  - Active selection displays a glowing primary border and checked state.
  - Selecting "High School" directs to Exam Board Selector (ONB-05).
  - Selecting "Higher Education" directs to Field of Study Selector (ONB-08).
- **Edge Cases:**
  - Tapping "Continue" with no selection: Button is disabled or displays a polite validation tooltip.
- **Automated Verification:** `flutter test test/features/onboarding/presentation/cubit/calibration_cubit_test.dart`

---

### ONB-05: High School Exam Board Selector
- **Preconditions:** User selected "High School" track.
- **Step-by-Step Test Steps:**
  1. Inspect displayed exam board options: WAEC, JAMB (UTME), NECO, IGCSE, SAT, and Post-UTME.
  2. Select **"JAMB"**.
  3. Toggle between single-select and multi-select (e.g. WAEC + JAMB dual prep).
  4. Tap **"Continue"**.
- **Expected Results:**
  - Selected chip(s) highlight instantly.
  - The chosen board(s) are stored in `CalibrationCubit` state.
- **Edge Cases:**
  - Deselecting all chips: "Continue" button safely disables.
- **Automated Verification:** `flutter test test/features/onboarding/presentation/steps/high_school_exam_step_test.dart`

---

### ONB-06: Subject Multi-Select Matrix
- **Preconditions:** High school exam board selected.
- **Step-by-Step Test Steps:**
  1. Verify displayed subjects match the chosen exam board (e.g. JAMB displays English, Mathematics, Physics, Chemistry, Biology, Economics, etc.).
  2. Tap 4 subjects (e.g. English + Mathematics + Physics + Chemistry).
  3. Use the search bar at the top to filter subjects by keyword (e.g., "Gov" -> Government).
  4. Tap **"Continue"**.
- **Expected Results:**
  - Subject count badge updates in real time (e.g., "4/9 Selected").
  - Filter bar responds instantaneously.
  - Selections persist in Drift database upon submission.
- **Edge Cases:**
  - Selecting 0 subjects: Error toast appears ("Select at least 1 subject").
- **Automated Verification:** `flutter test test/features/onboarding/presentation/steps/high_school_subjects_step_test.dart`

---

### ONB-07: Target Exam Countdown Picker
- **Preconditions:** High school track and subjects configured.
- **Step-by-Step Test Steps:**
  1. Tap the date picker to set the primary exam target date (e.g. 60 days in the future).
  2. Observe the calculated "Days Remaining" counter and estimated daily study quota.
  3. Set a date in the past.
  4. Tap **"Continue"**.
- **Expected Results:**
  - Selecting a future date displays clear countdown badges (e.g., "60 Days to JAMB 2026").
  - Selecting a past date is disallowed by the date picker validation.
- **Edge Cases:**
  - Selecting today's date: Shows "Exam is Today! Entering Emergency High-Yield Mode".
- **Automated Verification:** `flutter test test/features/onboarding/presentation/steps/high_school_timeline_step_test.dart`

---

### ONB-08: Higher Ed Field of Study Step
- **Preconditions:** User selected "Higher Education" in ONB-04.
- **Step-by-Step Test Steps:**
  1. Inspect major discipline categories: STEM, Health Sciences / Medicine, Law & Legal Studies, Commercial / Business, Humanities & Arts.
  2. Select **"Health Sciences / Medicine"**.
  3. Select or enter specific major (e.g., "Human Anatomy & Physiology").
  4. Tap **"Continue"**.
- **Expected Results:**
  - Field category card expands with sub-specialties.
  - Selected discipline maps to medical deck taxonomy and AI prompt persona.
- **Edge Cases:**
  - Custom text input with special characters: Sanitized without SQL/script injection errors.
- **Automated Verification:** `flutter test test/features/onboarding/presentation/steps/higher_ed_field_step_test.dart`

---

### ONB-09: Higher Ed Academic Level Step
- **Preconditions:** Field of study selected.
- **Step-by-Step Test Steps:**
  1. Select academic level: 100L (Freshman), 200L (Sophomore), 300L (Junior), 400L (Senior), 500L (Final Year STEM), or Postgraduate.
  2. Tap **"300L"** and tap **"Continue"**.
- **Expected Results:**
  - Active level persists in user profile metadata in Drift and Supabase `profiles` table.
- **Automated Verification:** `flutter test test/features/onboarding/presentation/steps/higher_ed_level_step_test.dart`

---

### ONB-10: Higher Ed Target Goals Step
- **Preconditions:** Academic level selected.
- **Step-by-Step Test Steps:**
  1. Select Target GPA / Grade Goal (First Class / 4.50-5.00 GPA, Second Class Upper, Distinctions, Pass).
  2. Select Daily Target Review Count (e.g., 50 cards/day, 100 cards/day).
  3. Tap **"Continue"**.
- **Expected Results:**
  - Daily study goals update the dashboard target ring configuration.
- **Automated Verification:** `flutter test test/features/onboarding/presentation/steps/higher_ed_goals_step_test.dart`

---

### ONB-11: Aura Mesh Shader Background
- **Preconditions:** Any screen with dynamic mesh gradient background active.
- **Step-by-Step Test Steps:**
  1. Launch screen on high-end device (Vulkan/Metal support).
  2. Observe dynamic fluid mesh shader movement and color blend.
  3. Launch on low-RAM (<2GB) or OpenGL legacy emulator.
- **Expected Results:**
  - High-end devices render GPU fragment shader smoothly at 60 FPS without high battery drain.
  - Low-spec devices trigger automatic fallback to high-efficiency linear gradients without crashes or shader compilation errors.
- **Automated Verification:** `flutter test test/shared/widgets/aura_mesh_nebula_test.dart`

---

### ONB-12: System Permissions Calibration
- **Preconditions:** Final step before dashboard entry.
- **Step-by-Step Test Steps:**
  1. Review contextual permission cards for **Notifications** and **Microphone**.
  2. Tap **"Enable Notifications"**. Verify in-app explanation dialog precedes the native OS permission prompt.
  3. Accept or Deny the native prompt.
  4. Tap **"Continue to Kortex"**.
- **Expected Results:**
  - Denying permission does not crash or block onboarding progression.
  - State is saved in `PermissionsCubit` so denied permissions are not re-prompted aggressively.
- **Edge Cases:**
  - Permanently denied permission: Settings CTA appears directing user to app system settings if requested later.
- **Automated Verification:** `flutter test test/features/onboarding/presentation/cubit/permissions_cubit_test.dart`

---

## Module 2: Dashboard & Smart Study Command Center

### DSH-01: Unified Feed Engine (`get_dashboard_feed`)
- **Preconditions:** Authenticated user with existing local study data.
- **Step-by-Step Test Steps:**
  1. Launch Dashboard.
  2. Inspect network/RPC inspector for `get_dashboard_feed`.
  3. Verify all modules (streak, due cards count, recent decks, active pods) populate synchronously.
  4. Perform pull-to-refresh on dashboard.
- **Expected Results:**
  - Feed loads completely in $<250\text{ms}$.
  - Pull-to-refresh fetches latest remote state and updates local Drift SQLite database.
- **Edge Cases:**
  - 100% Offline launch: Loads cached dashboard feed from Drift DB with zero error popups.
- **Automated Verification:** `flutter test test/features/dashboard/data/repositories/dashboard_repository_impl_test.dart`

---

### DSH-02: Streak Flame Tracker & Celebrations
- **Preconditions:** User completes daily study quota or maintains streak.
- **Step-by-Step Test Steps:**
  1. Observe flame icon and numeric counter on the top dashboard bar.
  2. Complete study of the required cards for the day.
  3. Tap the Streak badge to open Streak Milestone modal.
- **Expected Results:**
  - Streak increments by +1 upon completing daily target.
  - Flame glows with animated particle aura.
  - Reaching milestone (7, 30, 100 days) triggers confetti explosion and haptic feedback.
- **Edge Cases:**
  - Inactive for $>48$ hours: Streak resets to 1 (or prompts Streak Freeze if available).
- **Automated Verification:** `flutter test test/features/dashboard/presentation/widgets/streak_tracker_widget_test.dart`

---

### DSH-03: Daily Retention Progress Ring
- **Preconditions:** Daily card review quota configured (e.g., 50 cards).
- **Step-by-Step Test Steps:**
  1. Check initial state (e.g., 0/50 cards reviewed -> 0% radial ring).
  2. Review 25 cards in Flashcard Studio.
  3. Return to Dashboard and observe progress ring.
  4. Review remaining 25 cards to reach 100%.
- **Expected Results:**
  - Radial SVG ring fills proportionally with smooth ease-out animation.
  - Ring completes with a checkmark badge and green glow at 100%.
- **Automated Verification:** `flutter test test/features/dashboard/presentation/widgets/daily_target_ring_test.dart`

---

### DSH-04: One-Tap FSRS Quick Study CTA
- **Preconditions:** At least one deck has cards due for review.
- **Step-by-Step Test Steps:**
  1. View the prominent **"Start Study Session"** primary CTA button.
  2. Tap the CTA button.
- **Expected Results:**
  - Instantly navigates to `StudySessionPage` with the deck containing the highest count of overdue/high-urgency cards.
  - Transition happens in $<100\text{ms}$ with zero intermediate setup screens.
- **Edge Cases:**
  - Zero cards due in all decks: CTA gracefully updates to "All caught up! Practice CBT or Explore Community Decks".
- **Automated Verification:** `flutter test test/features/dashboard/presentation/pages/dashboard_page_test.dart`

---

### DSH-05: Quick Pomodoro Focus Module
- **Preconditions:** Dashboard page active.
- **Step-by-Step Test Steps:**
  1. Locate the Pomodoro quick-widget on dashboard.
  2. Select interval preset: **25 min** or **50 min**.
  3. Tap **"Start Focus"**.
  4. Allow timer to run, test Pause and Reset actions.
  5. Allow timer to reach 00:00.
- **Expected Results:**
  - Countdown ticks every second accurately.
  - Audio completion chime rings and haptic buzz triggers upon reaching 00:00.
  - Automatically switches to Break mode (5 min / 10 min).
- **Automated Verification:** `flutter test test/features/focus/presentation/cubit/focus_session_cubit_test.dart`

---

### DSH-06: Ambient Focus Audio Player
- **Preconditions:** Device volume turned on.
- **Step-by-Step Test Steps:**
  1. Tap the Ambient Audio player widget on the dashboard or focus bar.
  2. Select sound tracks: **Lo-Fi Study Beat**, **Gentle Rain**, **Alpha Binaural Waves (40Hz)**.
  3. Adjust the volume slider.
  4. Turn device to Airplane mode (100% offline) and trigger playback.
- **Expected Results:**
  - Audio plays seamlessly in a continuous loop without audible popping or stutter.
  - 100% functional offline from cached assets.
  - Audio pauses cleanly when a voice call or another primary audio stream takes focus.
- **Automated Verification:** `flutter test test/features/dashboard/presentation/services/ambient_audio_service_test.dart`

---

### DSH-07: Recent Decks Horizontal Carousel
- **Preconditions:** Multiple study decks exist in the local library.
- **Step-by-Step Test Steps:**
  1. Scroll horizontally through the Recent Decks carousel.
  2. Verify each deck card displays: Deck Title, Total Cards, Due Cards count, Mastery Percentage bar, and Last Studied timestamp.
  3. Tap on any deck card.
- **Expected Results:**
  - Carousel scrolls with inertia at 60 FPS.
  - Tapping a deck opens the Deck Detail / Study options sheet.
- **Automated Verification:** `flutter test test/features/dashboard/presentation/widgets/recent_decks_carousel_test.dart`

---

### DSH-08: Rapid Document Ingestion Quick-Tile
- **Preconditions:** Dashboard active.
- **Step-by-Step Test Steps:**
  1. Tap the **"Quick Upload / Scan"** action tile.
  2. Verify the modal bottom sheet presents 3 clear options: Camera OCR, Upload PDF/Document, and Audio Lecture.
  3. Select each option to ensure correct routing.
- **Expected Results:**
  - Sheet slides up smoothly with spring physics.
  - Tapping an option routes directly to the respective ingestion pipeline.
- **Automated Verification:** `flutter test test/features/dashboard/presentation/widgets/quick_upload_action_tile_test.dart`

---

### DSH-09: Live Study Pod Presence Strip
- **Preconditions:** Internet connection active.
- **Step-by-Step Test Steps:**
  1. View the Live Study Pod presence strip on the dashboard.
  2. Check the real-time active student counter (e.g. "42 students studying JAMB Physics right now").
  3. Tap on the strip.
- **Expected Results:**
  - Navigates immediately to Community Hub Live Rooms tab.
- **Edge Cases:**
  - Offline: Strip displays "Offline Mode — Study solo with FSRS & Syllabot".
- **Automated Verification:** `flutter test test/features/dashboard/presentation/widgets/live_pods_summary_widget_test.dart`

---

### DSH-10: Floating Syllabot AI Quick Drawer
- **Preconditions:** Dashboard or any main tab active.
- **Step-by-Step Test Steps:**
  1. Locate the floating Syllabot avatar button at the bottom-right corner.
  2. Drag the button across the screen to test gesture positioning.
  3. Tap the floating button.
- **Expected Results:**
  - Syllabot chat drawer slides up over current context without destroying background state.
  - Draggable button snaps smoothly to screen edges.
- **Automated Verification:** `flutter test test/features/syllabot/presentation/widgets/floating_syllabot_overlay_test.dart`

---

## Module 3: Flashcard Studio & Spaced Repetition (FSRS-6)

### FSR-01: FSRS-6 Mathematical Core
- **Preconditions:** Flashcard deck initialized with test cards.
- **Step-by-Step Test Steps:**
  1. Execute automated unit test suite for `FSRSScheduler`.
  2. Verify formulas for:
     - Retrievability $R(t, S) = (1 + \text{factor} \cdot \frac{t}{S})^{-0.5}$
     - Initial Stability $S_0(G)$ across grades $G \in \{1, 2, 3, 4\}$.
     - Difficulty updating $D' = \min(\max(D - \dots, 1), 10)$.
     - Next review interval $I = \frac{S}{\text{factor}} \cdot (r^{-\frac{1}{\text{decay}}} - 1)$.
  3. Verify retention target parameter bounds ($0.85$ to $0.95$).
- **Expected Results:**
  - 100% mathematical precision with zero rounding overflows or NaN values.
  - All 21 FSRS-6 weights correctly evaluated.
- **Automated Verification:** `flutter test test/features/flashcards/domain/usecases/fsrs_algorithm_engine_test.dart`

---

### FSR-02: 4-Button Grading Bar
- **Preconditions:** Card flipped to reveal answer.
- **Step-by-Step Test Steps:**
  1. Inspect the 4 grading buttons: **Again** (Red), **Hard** (Orange), **Good** (Blue), **Easy** (Green).
  2. Check the interval preview text beneath each button (e.g., Again: `<10m`, Hard: `1.2d`, Good: `3.5d`, Easy: `7.0d`).
  3. Tap **"Good"**.
- **Expected Results:**
  - Card grades immediately, schedules next review timestamp in SQLite `cards` table, logs entry into `review_logs`, and animates in the next card.
  - Haptic feedback fires on tap.
- **Automated Verification:** `flutter test test/features/flashcards/presentation/widgets/fsrs_rating_action_bar_test.dart`

---

### FSR-03: 3D Perspective Flip Card Canvas
- **Preconditions:** Active study session with a front/back flashcard.
- **Step-by-Step Test Steps:**
  1. Single-tap the card canvas.
  2. Observe the 3D Y-axis rotation matrix animation.
  3. Test horizontal swipe gestures (Swipe left -> Again, Swipe right -> Good).
- **Expected Results:**
  - Card flips smoothly at 60 FPS with realistic perspective depth (`Matrix4.identity()..setEntry(3, 2, 0.001)`).
  - Front content hides and back content renders at exactly $90^\circ$ rotation without mirror inversion.
- **Automated Verification:** `flutter test test/features/flashcards/presentation/widgets/flashcard_gesture_canvas_test.dart`

---

### FSR-04: KaTeX LaTeX & Chemical Equation Viewer
- **Preconditions:** Card containing LaTeX strings (e.g. `\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}` and `\ce{H2SO4 + 2NaOH -> Na2SO4 + 2H2O}`).
- **Step-by-Step Test Steps:**
  1. Load flashcard in review session.
  2. Verify visual rendering of fractions, radicals, integral signs, sub/superscripts, and chemical formulas.
  3. Pinch-to-zoom on complex formulas.
- **Expected Results:**
  - Math symbols render crisply with zero raw LaTeX string leakage.
  - Fast render time with cached syntax trees.
- **Automated Verification:** `flutter test test/features/flashcards/presentation/widgets/latex_card_content_viewer_test.dart`

---

### FSR-05: Syntax-Highlighted Code Block Viewer
- **Preconditions:** Flashcard containing programming code snippet in markdown (Python, Dart, C++, SQL).
- **Step-by-Step Test Steps:**
  1. Review a card with multi-line code blocks.
  2. Check keyword highlighting, string literals, comments, and line numbers.
  3. Tap the **"Copy Code"** icon in the code header.
- **Expected Results:**
  - Correct language token colors according to active app theme.
  - Copying code places clean text on system clipboard and displays a confirmation toast.
- **Automated Verification:** `flutter test test/features/flashcards/presentation/widgets/code_block_viewer_test.dart`

---

### FSR-06: ADHD Thought Parking Lot
- **Preconditions:** Active flashcard study session.
- **Step-by-Step Test Steps:**
  1. During card review, tap the **"Park Thought"** icon in the top header.
  2. Type a spontaneous thought (e.g., "Check grocery list after study").
  3. Tap **"Save & Continue"**.
- **Expected Results:**
  - Bottom sheet closes instantly and study card state is completely uninterrupted.
  - Thought is saved to Drift SQLite `thought_parking_lot` table and viewable in user profile later.
- **Automated Verification:** `flutter test test/features/flashcards/presentation/widgets/thought_parking_lot_sheet_test.dart`

---

### FSR-07: ADHD Full-Screen Immersion Mode
- **Preconditions:** Active study session.
- **Step-by-Step Test Steps:**
  1. Toggle **"Immersion Mode"** in study session settings.
  2. Observe UI changes.
- **Expected Results:**
  - System status bar, navigation bar, card counters, and background clutter are hidden.
  - Only the active card and grading buttons remain visible with pure black OLED background.
- **Automated Verification:** `flutter test test/features/flashcards/presentation/pages/focus_workspace_page_test.dart`

---

### FSR-08: Dynamic Bionic Reading Toggle
- **Preconditions:** Active study session.
- **Step-by-Step Test Steps:**
  1. Toggle **"Bionic Reading"** switch.
  2. Inspect text content across question and answer.
- **Expected Results:**
  - The first 40–50% of every word is bolded (e.g. "**Kort**ex is a **neu**ro-**inclu**sive **pla**tform").
  - Formatted text retains all italics, colors, and line breaks.
- **Automated Verification:** `flutter test test/shared/utils/bionic_text_formatter_test.dart`

---

### FSR-09: CRDT Deck Conflict-Free Merger
- **Preconditions:** Two devices editing the same deck offline simultaneously.
- **Step-by-Step Test Steps:**
  1. Device A modifies Card 1 while offline.
  2. Device B adds Card 2 and edits Card 1 while offline.
  3. Reconnect both devices to internet.
  4. Trigger sync and inspect merged deck state.
- **Expected Results:**
  - Merged deck contains Card 1 with Last-Write-Wins (LWW) field resolution and Card 2 is preserved.
  - Zero duplicate IDs or dropped cards.
- **Automated Verification:** `flutter test test/features/flashcards/domain/crdt/crdt_deck_merger_test.dart`

---

### FSR-10: Deck Export Engine (.apkg, JSON, CSV)
- **Preconditions:** Study deck with 50+ cards containing text, tags, and LaTeX.
- **Step-by-Step Test Steps:**
  1. Open Deck Settings -> **Export Deck**.
  2. Select format: **Anki (.apkg)**, **Kortex JSON**, or **Spreadsheet (.csv)**.
  3. Tap **"Export & Share"**.
- **Expected Results:**
  - File is compiled with correct zip/sqlite structure (.apkg) or UTF-8 encoded text (.json, .csv).
  - Native OS Share Sheet opens allowing file export/save.
- **Automated Verification:** `flutter test test/features/flashcards/presentation/widgets/export_deck_modal_sheet_test.dart`

---

### FSR-11: Card Tagging & Sub-Deck Hierarchy
- **Preconditions:** Decks with hierarchical names (`Biology::Cell::Mitosis`).
- **Step-by-Step Test Steps:**
  1. Open Deck Library.
  2. Inspect tree view representation.
  3. Expand parent deck "Biology" to reveal "Cell" and "Mitosis".
  4. Study parent deck "Biology".
- **Expected Results:**
  - Tree expands/collapses smoothly.
  - Studying parent deck aggregates due cards from all sub-decks recursively.
- **Automated Verification:** `flutter test test/features/decks/presentation/widgets/subdeck_hierarchy_tree_test.dart`

---

### FSR-12: Voice Card Auto-Pronunciation
- **Preconditions:** Card containing foreign language or complex medical terms.
- **Step-by-Step Test Steps:**
  1. Turn on "Auto-Pronounce on Flip" in deck settings.
  2. Flip card to answer.
  3. Tap manual speaker icon button.
- **Expected Results:**
  - Text-to-speech engine speaks the term cleanly with correct language locale.
- **Automated Verification:** `flutter test test/features/flashcards/presentation/widgets/audio_pronounce_button_test.dart`

---

### FSR-13: Image Occlusion Card Viewer
- **Preconditions:** Deck contains an image occlusion card (e.g. human heart diagram with labeled occluded boxes).
- **Step-by-Step Test Steps:**
  1. Open Image Occlusion card in study mode.
  2. Verify red mask covers the target label while other masks remain semi-transparent blue.
  3. Pinch to zoom in on intricate anatomical structures and pan across canvas.
  4. Tap target mask to reveal label.
  5. Tap **"Toggle All Masks"** button.
- **Expected Results:**
  - Pan and zoom gestures are responsive with zero visual clipping.
  - Tapped mask reveals correct hidden text with green border.
  - "Toggle All Masks" reveals all occlusions simultaneously.
- **Automated Verification:** `flutter test test/features/decks/presentation/widgets/image_occlusion_card_viewer_test.dart`

---

### FSR-14: Remedial Card Auto-Filter
- **Preconditions:** Deck with mixed card retention histories.
- **Step-by-Step Test Steps:**
  1. Select a deck with cards having Retrievability $<0.70$.
  2. Tap **"Cram Weak Cards / Remedial Filter"**.
- **Expected Results:**
  - Dynamic study session launches filtering strictly cards with $R < 0.70$ or Lapse Count $>2$.
  - Reviewing in cram mode does not negatively alter long-term FSRS scheduling stability.
- **Automated Verification:** `flutter test test/features/flashcards/domain/usecases/remedial_deck_generator_test.dart`

---

### FSR-15: Spaced Repetition Analytics Graph
- **Preconditions:** User has completed $>50$ reviews over multiple days.
- **Step-by-Step Test Steps:**
  1. Open Deck Analytics tab.
  2. Inspect Stability distribution chart, Difficulty histogram, and Retrievability decay curves.
- **Expected Results:**
  - Graphs render accurately with interactive tooltip scrubbers displaying exact card counts per bucket.
- **Automated Verification:** `flutter test test/features/flashcards/presentation/widgets/retention_heatmap_widget_test.dart`

---

## Module 4: Document Ingestion, OCR & Multimodal Synthesis

### ING-01: Multi-Format Document Drop Zone
- **Preconditions:** Ingestion Hub page open.
- **Step-by-Step Test Steps:**
  1. Tap Drop Zone or drag-and-drop files (Desktop/Web).
  2. Test supported file formats: `.pdf`, `.docx`, `.pptx`, `.txt`, `.png`, `.jpg`.
  3. Attempt to upload unsupported format (e.g. `.exe` or `.mp4`).
- **Expected Results:**
  - Supported files parse file name, size, and page count.
  - Unsupported files display error toast ("Unsupported file type. Please upload PDF, Word, PPTX, or Image").
- **Automated Verification:** `flutter test test/features/ingestion/presentation/widgets/file_drop_zone_widget_test.dart`

---

### ING-02: Live Camera OCR Document Scanner
- **Preconditions:** Physical mobile device with camera permission granted.
- **Step-by-Step Test Steps:**
  1. Tap **"Scan Textbook / Notes"**.
  2. Point camera at a printed textbook page.
  3. Observe live rectangular edge-detection bounding box.
  4. Tap the capture shutter button.
- **Expected Results:**
  - Shutter captures high-resolution still image, crops perspective distortion, and passes bitmap to OCR pipeline.
- **Automated Verification:** `flutter test test/features/ingestion/presentation/widgets/camera_live_ocr_overlay_test.dart`

---

### ING-03: On-Device ML Kit OCR Engine
- **Preconditions:** Captured document image. Device in 100% Airplane Mode (Offline).
- **Step-by-Step Test Steps:**
  1. Execute OCR on image while offline.
  2. Observe extracted text preview.
- **Expected Results:**
  - Google ML Kit extracts text locally in $<1.5\text{s}$ with zero cloud dependencies.
  - Text preserves paragraph breaks and list numbering.
- **Automated Verification:** `flutter test test/features/ingestion/data/clients/local_ml_kit_ocr_client_test.dart`

---

### ING-04: Mathematical LaTeX Formula OCR
- **Preconditions:** Photographed document containing math equations.
- **Step-by-Step Test Steps:**
  1. Run STEM OCR pipeline on photographed quadratic formula $\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$.
  2. Check output card preview.
- **Expected Results:**
  - Image formula is parsed into valid KaTeX markup (`\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}`).
- **Automated Verification:** `flutter test test/features/ingestion/domain/usecases/process_stem_ocr_use_case_test.dart`

---

### ING-05: Recursive Semantic Text Splitter
- **Preconditions:** Ingesting a 30-page PDF document.
- **Step-by-Step Test Steps:**
  1. Process document through text chunker.
  2. Inspect chunk boundaries.
- **Expected Results:**
  - Chunks are split on semantic paragraph/section boundaries ($1000$ tokens with $200$ token overlap) without slicing sentences in half.
- **Automated Verification:** `flutter test test/features/ingestion/domain/services/recursive_text_splitter_test.dart`

---

### ING-06: Deep Document Deduplication Service
- **Preconditions:** Document with repetitive bullet points or duplicate chapters.
- **Step-by-Step Test Steps:**
  1. Ingest text containing near-identical duplicate definitions.
  2. Inspect generated card candidate list.
- **Expected Results:**
  - Deduplication service flags and merges cards with Jaccard/Cosine similarity $>0.85$, eliminating redundancy.
- **Automated Verification:** `flutter test test/features/ingestion/domain/services/deep_document_dedup_service_test.dart`

---

### ING-07: High-Yield / Comprehensive Mode Selector
- **Preconditions:** Document ingestion configuration step.
- **Step-by-Step Test Steps:**
  1. Toggle between **"High-Yield (Key Concepts Only ~10-15 cards)"** and **"Comprehensive (Deep Coverage ~50+ cards)"**.
  2. Generate flashcards for both modes.
- **Expected Results:**
  - High-yield mode generates concise definitions and high-exam-probability Q&As.
  - Comprehensive mode extracts all formulas, examples, and edge terms.
- **Automated Verification:** `flutter test test/features/ingestion/presentation/widgets/synthesis_mode_toggle_test.dart`

---

### ING-08: Ingestion Live Review & LaTeX Split Screen
- **Preconditions:** Flashcards generated from OCR/PDF.
- **Step-by-Step Test Steps:**
  1. View `GeneratedCardsReviewPage`.
  2. Inspect side-by-side split screen showing source snippet on left/top and editable generated card on right/bottom.
  3. Edit card front/back text, fix a typo, and delete an unwanted card.
  4. Tap **"Save Deck to Library"**.
- **Expected Results:**
  - Inline edits update instantly with live KaTeX preview.
  - Deleted card removes from array.
  - "Save Deck" inserts all verified cards into Drift SQLite and sync queue.
- **Automated Verification:** `flutter test test/features/ingestion/presentation/pages/generated_cards_review_page_test.dart`

---

### ING-09: LMS Syllabus Integration (Canvas/Moodle/Google Classroom)
- **Preconditions:** LMS Import sheet open.
- **Step-by-Step Test Steps:**
  1. Select LMS Provider: **Canvas**, **Moodle**, or **Google Classroom**.
  2. Complete OAuth institution authentication.
  3. Select an active course syllabus (e.g. "CSC 301: Algorithms").
  4. Tap **"Import Syllabus & Build Deck"**.
- **Expected Results:**
  - Course modules, weekly readings, and exam milestones are imported.
  - Auto-generates structured sub-decks per week/topic.
- **Edge Cases:**
  - Invalid OAuth token / Expired session: Displays friendly re-authentication prompt without crashing.
- **Automated Verification:** `flutter test test/features/ingestion/presentation/widgets/lms_import_modal_sheet_test.dart`

---

### ING-10: Audio Lecture Ingestion & Transcription
- **Preconditions:** Microphone or recorded audio file (`.m4a`, `.mp3`, `.wav`).
- **Step-by-Step Test Steps:**
  1. Open `AudioLectureIngestionSheet`.
  2. Record a 60-second lecture audio snippet or pick an audio file.
  3. Observe progressive upload indicator and live transcription stream.
  4. Tap **"Generate Study Deck from Audio"**.
- **Expected Results:**
  - Audio uploads in chunked streams.
  - Speech-to-text converts spoken words into punctuated transcript.
  - Generates accurate flashcards summarizing the lecture audio.
- **Automated Verification:** `flutter test test/features/ingestion/presentation/widgets/audio_lecture_ingestion_sheet_test.dart`

---

### ING-11: Cloud AI Flashcard Extraction Pipeline
- **Preconditions:** Online device with Gemini Cloud API connected.
- **Step-by-Step Test Steps:**
  1. Ingest a 5-page text document using Cloud mode.
  2. Monitor network response and card schema validation.
- **Expected Results:**
  - Gemini Flash extracts well-formed JSON Q&A pairs adhering to strict schema in $<3.5\text{s}$.
- **Automated Verification:** `flutter test test/features/ingestion/data/clients/gemini_flashcard_extractor_test.dart`

---

### ING-12: Local Offline AI Flashcard Extraction
- **Preconditions:** Device in Airplane mode with quantized on-device SLM model file downloaded.
- **Step-by-Step Test Steps:**
  1. Ingest text document while offline.
  2. Monitor extraction progress bar.
- **Expected Results:**
  - Local quantized model isolate executes inference in background thread.
  - Flashcards generate offline without internet connection or UI frame drops.
- **Automated Verification:** `flutter test test/features/ingestion/data/clients/local_llm_engine_client_test.dart`

---

## Module 5: Syllabot AI: Socratic Learning & Multimodal Assistant

### SYL-01: Socratic Guidance Dialogue Engine
- **Preconditions:** Open Syllabot chat and select "Socratic Tutor" mode.
- **Step-by-Step Test Steps:**
  1. Send message: *"What is the answer to question 5 on the thermodynamics test?"*
  2. Send message: *"I don't understand how entropy relates to the second law."*
- **Expected Results:**
  - Syllabot refuses to provide direct test answers.
  - Syllabot responds with guiding Socratic questions, conceptual breakdowns, and hints encouraging active critical thinking.
- **Automated Verification:** `flutter test test/features/syllabot/presentation/cubit/syllabot_chat_cubit_test.dart`

---

### SYL-02: Explanatory & Step-by-Step Proof Mode
- **Preconditions:** Switch mode to "Step-by-Step Proof".
- **Step-by-Step Test Steps:**
  1. Ask: *"Derive the quadratic formula by completing the square."*
- **Expected Results:**
  - Syllabot outputs a numbered step-by-step derivation with formatted KaTeX formulas at every step.
- **Automated Verification:** `flutter test test/features/syllabot/presentation/pages/syllabot_chat_page_test.dart`

---

### SYL-03: Real-World Analogy Generator
- **Preconditions:** Switch mode to "Analogy Mode".
- **Step-by-Step Test Steps:**
  1. Ask: *"Explain how TCP 3-way handshake works."*
- **Expected Results:**
  - Syllabot provides a memorable, real-world metaphor (e.g. phone call greeting or sending certified letters) before giving technical definitions.
- **Automated Verification:** `flutter test test/features/syllabot/domain/prompts/analogy_mode_prompt_test.dart`

---

### SYL-04: Document RAG Vector Search
- **Preconditions:** User has uploaded a course textbook PDF.
- **Step-by-Step Test Steps:**
  1. Ask a specific question from Chapter 4 of the uploaded textbook.
  2. Observe vector retrieval query execution.
- **Expected Results:**
  - Syllabot grounds its response strictly in the uploaded document's context and highlights relevant source excerpts.
- **Automated Verification:** `flutter test test/features/syllabot/data/clients/vector_search_client_test.dart`

---

### SYL-05: Clickable RAG Citation Chips
- **Preconditions:** RAG-grounded response received.
- **Step-by-Step Test Steps:**
  1. Observe citation badges attached to AI response (e.g., `[Doc: Organic_Chem_Ch3.pdf • Page 42]`).
  2. Tap on the citation badge.
- **Expected Results:**
  - Opens `RagSourceInspectionSheet` showing exact paragraph excerpt and document page preview.
- **Automated Verification:** `flutter test test/features/syllabot/presentation/widgets/rag_reference_badge_test.dart`

---

### SYL-06: Real-Time Speech-to-Text Microphone
- **Preconditions:** Microphone permission granted.
- **Step-by-Step Test Steps:**
  1. Tap and hold (or tap to toggle) the microphone icon button in the chat input bar.
  2. Speak a physics question: *"How does electromagnetic induction generate current?"*
  3. Observe live audio waveform animation.
  4. Release/Stop speaking.
- **Expected Results:**
  - Waveform mirrors voice amplitude in real time.
  - Spoken words convert accurately to text in the chat input field.
- **Automated Verification:** `flutter test test/features/syllabot/presentation/widgets/audio_input_waveform_button_test.dart`

---

### SYL-07: Text-to-Speech Natural Voice Engine
- **Preconditions:** Syllabot response rendered on screen.
- **Step-by-Step Test Steps:**
  1. Tap the speaker icon on any AI message bubble.
  2. Tap speaker icon again during playback.
- **Expected Results:**
  - Synthesizes speech with natural cadence.
  - Second tap pauses/stops audio immediately.
- **Automated Verification:** `flutter test test/features/syllabot/presentation/services/text_to_speech_handler_test.dart`

---

### SYL-08: Chat-to-Deck One-Click Synthesis
- **Preconditions:** Syllabot discussion with rich explanations.
- **Step-by-Step Test Steps:**
  1. Tap the **"Convert Chat to Flashcards"** action button in the chat menu.
  2. Select target deck or create a new deck name.
  3. Tap **"Generate Cards"**.
- **Expected Results:**
  - Syllabot extracts core concepts from the conversation history and opens the card review sheet with generated Q&As.
- **Automated Verification:** `flutter test test/features/syllabot/presentation/widgets/convert_to_deck_action_sheet_test.dart`

---

### SYL-09: Hybrid Cloud/Local AI Router
- **Preconditions:** App online, then switched to airplane mode.
- **Step-by-Step Test Steps:**
  1. Send chat message while online -> Verify routed to Cloud Gemini.
  2. Switch device to Airplane mode.
  3. Send chat message while offline -> Verify routed to Local on-device GGUF SLM.
- **Expected Results:**
  - Router seamlessly switches engine without displaying network connection error dialogs to user.
- **Automated Verification:** `flutter test test/features/syllabot/domain/services/execution_engine_router_test.dart`

---

### SYL-10: Local Quantized Model Isolate Worker
- **Preconditions:** Local model running inference.
- **Step-by-Step Test Steps:**
  1. Trigger local offline AI generation while scrolling chat list and animating UI.
- **Expected Results:**
  - Heavy tensor computations execute in separate background Dart Isolate.
  - Main UI thread maintains consistent 60 FPS with zero frame drops or jank.
- **Automated Verification:** `flutter test test/features/syllabot/data/isolates/local_inference_isolate_manager_test.dart`

---

### SYL-11: Engine Status Live Badge
- **Preconditions:** Syllabot chat page active.
- **Step-by-Step Test Steps:**
  1. Observe header engine indicator under different conditions:
     - Online: `Cloud ⚡ (Gemini 1.5 Flash)`
     - Offline Cached: `Cached 💾`
     - Offline Inference: `Local 🧠 (Quantized SLM)`
- **Expected Results:**
  - Badge dynamically reflects exact active engine state and latency.
- **Automated Verification:** `flutter test test/features/syllabot/presentation/widgets/engine_status_indicator_test.dart`

---

### SYL-12: Multi-Turn Conversational Memory Buffer
- **Preconditions:** Active Syllabot chat session.
- **Step-by-Step Test Steps:**
  1. Send: *"Let's study the French Revolution."*
  2. Send: *"Who was the king during this time?"* (Pronoun reference test).
  3. Send: *"When was he executed?"*
- **Expected Results:**
  - Syllabot maintains context across turns (identifies King Louis XVI without needing the user to repeat the topic).
  - Context buffer truncates/summarizes older turns when exceeding 8k tokens without crashing.
- **Automated Verification:** `flutter test test/features/syllabot/data/services/conversation_history_manager_test.dart`

---

### SYL-13: Math Formula Scratchpad in Chat
- **Preconditions:** Syllabot chat open.
- **Step-by-Step Test Steps:**
  1. Tap the **"Math Scratchpad"** icon in the chat input toolbar.
  2. Draw a mathematical symbol (e.g. $\Sigma$ or $\sqrt{x}$) freehand on the canvas.
  3. Tap **"Insert Formula"**.
- **Expected Results:**
  - Scratchpad converts handwriting into KaTeX syntax and inserts it into the active chat prompt.
- **Automated Verification:** `flutter test test/features/syllabot/presentation/widgets/chat_latex_scratchpad_widget_test.dart`

---

### SYL-14: AI Persona & Rigor Customizer
- **Preconditions:** Syllabot Settings open.
- **Step-by-Step Test Steps:**
  1. Select Persona: **Encouraging Mentor**, **Strict Academic Examiner**, or **Concise Bullet-Point Master**.
  2. Set Rigor Level: **High School (Introductory)** vs **University (Rigorous Proofs)**.
  3. Send a test message.
- **Expected Results:**
  - AI responses adapt tone, vocabulary, and depth according to chosen settings.
- **Automated Verification:** `flutter test test/features/syllabot/presentation/pages/syllabot_ai_settings_page_test.dart`

---

## Module 6: Gamified Quiz Arena & CBT Practice Engine

### QZ-01: Past Questions Bank & Search Engine
- **Preconditions:** Past questions database populated in Drift SQLite.
- **Step-by-Step Test Steps:**
  1. Navigate to Past Questions tab.
  2. Apply filters: **Exam Board = JAMB**, **Subject = Physics**, **Year = 2024**, **Topic = Waves & Optics**.
  3. Enter search keyword in search bar: *"Refraction"*.
- **Expected Results:**
  - Filtered list returns matching questions in $<100\text{ms}$.
  - Question stem, diagram (if any), and options A-D render clearly.
- **Automated Verification:** `flutter test test/features/quiz/presentation/pages/past_questions_board_page_test.dart`

---

### QZ-02: Timed CBT Exam Simulator
- **Preconditions:** Configure CBT Practice: 40 Questions, 40 Minutes, Negative Marking = ON.
- **Step-by-Step Test Steps:**
  1. Tap **"Start CBT Simulator"**.
  2. Verify countdown timer begins at 40:00.
  3. Answer questions, skip questions, mark questions for review.
  4. Allow timer to reach 00:00.
- **Expected Results:**
  - Reaching 00:00 triggers automatic auto-submission.
  - Saves all answers and directs immediately to Diagnostic Results page.
- **Automated Verification:** `flutter test test/features/quiz/presentation/cubit/cbt_session_cubit_test.dart`

---

### QZ-03: Accessible MCQ Option Cards
- **Preconditions:** CBT session active.
- **Step-by-Step Test Steps:**
  1. Tap option `(B)`.
  2. Observe visual state changes (Selected border, high-contrast checkmark).
  3. Turn on TalkBack/VoiceOver and tap option cards.
- **Expected Results:**
  - Clear visual distinction for active selection.
  - Screen reader announces: *"Option B: 9.8 meters per second squared, selected, 2 of 4"*.
- **Automated Verification:** `flutter test test/features/quiz/presentation/widgets/mcq_option_card_test.dart`

---

### QZ-04: Step-by-Step Solution Accordion
- **Preconditions:** Reviewing completed quiz or practice question.
- **Step-by-Step Test Steps:**
  1. Tap **"View Detailed Explanation"** on a question.
  2. Verify expanded accordion contains: Correct Answer Key, Step-by-step calculation with LaTeX, Syllabus Reference, and Common Pitfalls.
- **Expected Results:**
  - Accordion expands smoothly without layout overflows.
  - Math formulas render with full KaTeX formatting.
- **Automated Verification:** `flutter test test/features/quiz/presentation/widgets/explanation_accordion_test.dart`

---

### QZ-05: Millionaire 15-Tier XP Ladder
- **Preconditions:** Launch "Study Millionaire" game mode.
- **Step-by-Step Test Steps:**
  1. Answer questions 1 through 5 correctly -> Reach Safe Haven Tier 5 ($1,000$ XP).
  2. Answer question 6 incorrectly.
- **Expected Results:**
  - XP ladder highlights current tier progress with gold animations.
  - Wrong answer drops user to last safe haven (Tier 5) rather than 0 XP.
- **Automated Verification:** `flutter test test/features/quiz/domain/engines/millionaire_tiering_engine_test.dart`

---

### QZ-06: 50:50 Lifeline Algorithm
- **Preconditions:** Active Millionaire quiz session.
- **Step-by-Step Test Steps:**
  1. On a 4-option question, tap the **"50:50"** lifeline icon.
- **Expected Results:**
  - Exactly two incorrect options fade out and become unclickable.
  - Correct option and one random distractor remain active.
  - 50:50 lifeline button is disabled for remainder of the game.
- **Automated Verification:** `flutter test test/features/quiz/presentation/widgets/millionaire_lifeline_bar_test.dart`

---

### QZ-07: Audience Poll Simulation Dialog
- **Preconditions:** Active Millionaire quiz session.
- **Step-by-Step Test Steps:**
  1. Tap the **"Audience Poll"** lifeline.
- **Expected Results:**
  - Animated bar chart dialog pops up showing simulated percentage distribution across options A, B, C, D (heavily weighted towards correct answer on early tiers, higher variance on high tiers).
- **Automated Verification:** `flutter test test/features/quiz/presentation/widgets/millionaire_audience_poll_dialog_test.dart`

---

### QZ-08: Phone-an-AI Mentor Lifeline
- **Preconditions:** Active Millionaire quiz session.
- **Step-by-Step Test Steps:**
  1. Tap **"Ask Syllabot AI"** lifeline.
- **Expected Results:**
  - Syllabot bottom sheet opens with a 30-second countdown timer.
  - Syllabot provides a clever conceptual hint without giving away the direct letter.
- **Automated Verification:** `flutter test test/features/quiz/presentation/widgets/millionaire_lifeline_bar_test.dart`

---

### QZ-09: Diagnostic Quiz Results Radar Chart
- **Preconditions:** Quiz session submitted.
- **Step-by-Step Test Steps:**
  1. View `QuizResultsPage`.
  2. Inspect the radar chart showing mastery across tested topics (e.g., Mechanics: 90%, Thermodynamics: 40%, Waves: 75%).
- **Expected Results:**
  - Radar chart plots axes accurately with color coding (Green $\ge 70\%$, Amber $50-69\%$, Red $<50\%$).
- **Automated Verification:** `flutter test test/features/quiz/presentation/pages/quiz_results_page_test.dart`

---

### QZ-10: Convert Failed Questions to Deck
- **Preconditions:** Quiz submitted with 5 incorrect answers.
- **Step-by-Step Test Steps:**
  1. On Quiz Results page, tap **"Create Flashcard Deck from Missed Questions"**.
  2. Enter deck name or accept default (e.g., *"Remedial: JAMB Physics Missed"*).
  3. Tap **"Create Deck"**.
- **Expected Results:**
  - Creates a new FSRS deck in Drift SQLite containing the 5 missed questions, explanations, and formulas.
  - Displays success snackbar and CTA to start studying.
- **Automated Verification:** `flutter test test/features/quiz/domain/usecases/convert_failed_quiz_to_deck_use_case_test.dart`

---

### QZ-11: OCR Past Question Camera Importer
- **Preconditions:** Physical paper past question paper.
- **Step-by-Step Test Steps:**
  1. Tap **"Add Custom Past Question -> Scan with Camera"**.
  2. Snap photo of single MCQ question.
- **Expected Results:**
  - OCR extracts question stem, options A-D, and auto-detects answer key if highlighted.
  - Opens review sheet for teacher/student verification before saving to database.
- **Automated Verification:** `flutter test test/features/quiz/presentation/widgets/add_past_question_modal_test.dart`

---

### QZ-12: Negative Marking Warning Alerts
- **Preconditions:** CBT Practice setup with negative marking toggled ON.
- **Step-by-Step Test Steps:**
  1. Start exam.
  2. Verify warning banner appears at top: *"⚠️ Negative Marking Enabled (-0.25 per wrong answer). Leave blank if unsure."*
  3. Verify score calculation deducts penalty for incorrect answers on results page.
- **Expected Results:**
  - Negative marks are computed correctly ($(\text{Correct} \times 1.0) - (\text{Wrong} \times 0.25)$).
- **Automated Verification:** `flutter test test/features/quiz/presentation/cubit/cbt_session_cubit_test.dart`

---

### QZ-13: Peer-to-Peer 1v1 Quiz Duel
- **Preconditions:** Two connected devices / users in Quiz Duel Lobby.
- **Step-by-Step Test Steps:**
  1. Player 1 invites Player 2 (or selects Quick Matchmaking).
  2. Both players enter `QuizDuelArenaPage`.
  3. Answer question simultaneously.
  4. Player 1 answers in 2 seconds (Correct); Player 2 answers in 6 seconds (Correct).
  5. Tap emoji reaction button (🔥).
- **Expected Results:**
  - Real-time split scoreboard updates instantly over WebSocket.
  - Player 1 receives speed bonus points.
  - Floating emoji reaction appears on both players' screens.
  - If opponent disconnects, AI study-buddy fallback seamlessly takes over match.
- **Automated Verification:** `flutter test test/features/quiz/presentation/pages/quiz_duel_arena_page_test.dart`

---

### QZ-14: Question Flagging & Quality Audit
- **Preconditions:** Viewing any question in quiz practice or results.
- **Step-by-Step Test Steps:**
  1. Tap the flag icon on a question.
  2. Select issue type: **Typo / Formatting**, **Incorrect Answer Key**, **LaTeX Render Bug**, or **Outdated Syllabus**.
  3. Add optional explanation note and tap **"Submit Report"**.
- **Expected Results:**
  - Submits report to moderation endpoint and queues offline if disconnected.
  - Displays confirmation badge: *"Thank you for improving question quality!"*
- **Automated Verification:** `flutter test test/features/quiz/presentation/widgets/flag_question_bottom_sheet_test.dart`

---

### QZ-15: Audio Reading of Quiz Questions
- **Preconditions:** CBT question on screen.
- **Step-by-Step Test Steps:**
  1. Tap the speaker icon beside the question stem.
  2. Listen to audio playback.
- **Expected Results:**
  - TTS reads question stem followed sequentially by options A, B, C, and D.
- **Automated Verification:** `flutter test test/features/quiz/presentation/widgets/quiz_audio_reader_button_test.dart`

---

### QZ-16: Offline CBT Question Cache
- **Preconditions:** Airplane Mode enabled.
- **Step-by-Step Test Steps:**
  1. Navigate to Past Questions and start a 40-question CBT exam.
  2. Complete full exam and view explanations.
- **Expected Results:**
  - 100% functional without internet connectivity using pre-seeded Drift SQLite questions database.
- **Automated Verification:** `flutter test test/features/quiz/data/datasources/past_questions_dao_test.dart`

---

## Module 7: Community Hub, Body Doubling & Live Study Rooms

### COM-01: Auto-Provisioned Track Communities
- **Preconditions:** User completed onboarding calibration with "JAMB Medicine & Health Sciences".
- **Step-by-Step Test Steps:**
  1. Navigate to Community tab.
  2. Observe auto-joined community channel banner.
- **Expected Results:**
  - User is automatically placed in the matching track community (e.g. *"JAMB Medical Aspirants Hub"*) without manual search friction.
- **Automated Verification:** `flutter test test/features/community/presentation/cubit/auto_community_cubit_test.dart`

---

### COM-02: LiveKit Spatial Voice Pods
- **Preconditions:** Microphone permission granted, internet connected.
- **Step-by-Step Test Steps:**
  1. Join an active Live Study Room.
  2. Observe connected participant avatar grid.
  3. Speak into microphone.
- **Expected Results:**
  - Connects to LiveKit audio room in $<800\text{ms}$.
  - Active speaker avatar displays an animated glowing green ring responding to voice amplitude.
- **Automated Verification:** `flutter test test/features/community/data/services/livekit_audio_service_impl_test.dart`

---

### COM-03: Microphone Permission Guard
- **Preconditions:** Microphone permission revoked/denied in OS settings.
- **Step-by-Step Test Steps:**
  1. Attempt to join a voice study room.
- **Expected Results:**
  - In-app permission guard bottom sheet appears explaining why audio is required.
  - Tapping **"Grant Permission"** launches OS permission dialog or routes to App System Settings if permanently denied.
- **Automated Verification:** `flutter test test/features/community/presentation/pages/live_study_room_page_test.dart`

---

### COM-04: Synchronized Group Pomodoro Timer
- **Preconditions:** 3 users in the same Live Study Room.
- **Step-by-Step Test Steps:**
  1. Host starts a 25-minute group Pomodoro session.
  2. Compare timer displays across all 3 devices simultaneously.
- **Expected Results:**
  - All devices show identical countdown time synchronized via Supabase Realtime / NTP time compensation ($\Delta t < 200\text{ms}$).
- **Automated Verification:** `flutter test test/features/community/data/clients/ephemeral_presence_client_test.dart`

---

### COM-05: Real-Time Collaborative Whiteboard
- **Preconditions:** Live Study Room with Whiteboard open.
- **Step-by-Step Test Steps:**
  1. User A draws a circuit diagram on the whiteboard canvas.
  2. Observe User B's screen.
  3. User B selects highlighter tool and writes text.
- **Expected Results:**
  - Stroke vectors stream smoothly with RLE compression and render with $<50\text{ms}$ latency.
  - Supports pen colors, thickness, eraser, and clear canvas tools.
- **Automated Verification:** `flutter test test/features/community/presentation/widgets/whiteboard_canvas_widget_test.dart`

---

### COM-06: In-Room Flashcard Study Workspace
- **Preconditions:** Inside an active Live Voice Room.
- **Step-by-Step Test Steps:**
  1. Tap **"Open Flashcard Workspace"** inside the room.
  2. Select personal or shared room deck.
  3. Review cards while voice audio continues playing.
- **Expected Results:**
  - Study cards render in a split/overlay view without interrupting live room audio or dropping voice connections.
- **Automated Verification:** `flutter test test/features/community/presentation/widgets/in_room_deck_study_workspace_test.dart`

---

### COM-07: Floating Live Emoji Reactions
- **Preconditions:** Inside Live Study Room.
- **Step-by-Step Test Steps:**
  1. Tap floating reaction buttons: 🔥, 👏, 💡, 🧠.
- **Expected Results:**
  - Floating emoji particles rise upward and fade out across all participants' screens.
- **Automated Verification:** `flutter test test/features/community/presentation/widgets/floating_reaction_overlay_test.dart`

---

### COM-08: In-Room Real-Time Chat Drawer
- **Preconditions:** Inside Live Study Room.
- **Step-by-Step Test Steps:**
  1. Open Chat Drawer.
  2. Send text message and a KaTeX math snippet (`x = \frac{-b \pm \sqrt{D}}{2a}`).
- **Expected Results:**
  - Text and math formulas deliver in real time with unread message badges.
- **Automated Verification:** `flutter test test/features/community/presentation/widgets/room_chat_drawer_test.dart`

---

### COM-09: Micro Study Circles (2–8 Students)
- **Preconditions:** Community Hub open.
- **Step-by-Step Test Steps:**
  1. Tap **"Create Study Circle"**.
  2. Set name: *"UTME 300+ Squad"*, Max Members: 6, Privacy: Private (Passcode).
  3. Invite friend via share link or invite code.
- **Expected Results:**
  - Circle is created; entering passcode grants access; member list displays online status.
- **Automated Verification:** `flutter test test/features/community/presentation/widgets/create_study_circle_sheet_test.dart`

---

### COM-10: Threaded Subject Discussion Forums
- **Preconditions:** Track Community Forum open.
- **Step-by-Step Test Steps:**
  1. Create new discussion thread: Title, Subject Tag, Body (Markdown + LaTeX).
  2. Post a reply to the thread.
  3. Upvote the reply and mark as "Verified Solution".
- **Expected Results:**
  - Post and replies render correctly with formatted math.
  - Verified solution pin moves to top of discussion.
- **Automated Verification:** `flutter test test/features/community/presentation/pages/forum_thread_detail_page_test.dart`

---

### COM-11: Global & Track Streak Leaderboards
- **Preconditions:** Community Leaderboard tab active.
- **Step-by-Step Test Steps:**
  1. Toggle between **"Track Leaderboard"** and **"Global Top 100"**.
  2. Observe user's own rank card pinned at bottom of screen.
- **Expected Results:**
  - Displays top students ranked by Streak Days and Weekly XP.
  - User's rank is highlighted with quick jump to position.
- **Automated Verification:** `flutter test test/features/community/presentation/widgets/streak_leaderboard_widget_test.dart`

---

### COM-12: Community Deck Marketplace
- **Preconditions:** Marketplace tab open.
- **Step-by-Step Test Steps:**
  1. Browse decks by Popular, Highest Rated, and Newly Added.
  2. Search for *"Organic Chemistry"*.
  3. Tap on deck card to view preview (Card count, rating, author, sample cards).
- **Expected Results:**
  - Fast search filtering with rating stars, card sample modal, and author avatar.
- **Automated Verification:** `flutter test test/features/community/presentation/pages/deck_marketplace_detail_page_test.dart`

---

### COM-13: One-Tap Deck Cloning with FSRS Init
- **Preconditions:** Viewing community deck in marketplace.
- **Step-by-Step Test Steps:**
  1. Tap **"Clone Deck to My Library"**.
  2. Navigate to personal Flashcard Library.
- **Expected Results:**
  - Clones all cards, tags, and formulas into local Drift SQLite database.
  - Initializes fresh FSRS stability counters ($S=0, D=0$) tailored to the new user.
- **Automated Verification:** `flutter test test/features/community/domain/usecases/clone_shared_deck_use_case_test.dart`

---

### COM-14: Deck Publishing & Moderation
- **Preconditions:** User has a custom-created deck with 10+ cards.
- **Step-by-Step Test Steps:**
  1. Open Deck Settings -> **"Publish to Community Marketplace"**.
  2. Add description, tags, select academic track, and tap **"Publish"**.
- **Expected Results:**
  - Deck submits to marketplace catalog with status "Public".
- **Automated Verification:** `flutter test test/features/community/presentation/widgets/publish_deck_modal_sheet_test.dart`

---

### COM-15: Background Audio Session Recovery
- **Preconditions:** Inside a LiveKit voice study room.
- **Step-by-Step Test Steps:**
  1. Simulate an incoming phone call or background the app for 30 seconds.
  2. Decline/end call and return to Kortex.
- **Expected Results:**
  - Voice room audio automatically resumes and reconnects cleanly without requiring user to leave and rejoin room manually.
- **Automated Verification:** `flutter test test/features/community/data/services/livekit_audio_service_impl_test.dart`

---

### COM-16: Participant Mute/Deafen Controls
- **Preconditions:** Inside Live Study Room.
- **Step-by-Step Test Steps:**
  1. Tap **Mute** button (microphone icon).
  2. Tap **Deafen** button (headphone icon).
- **Expected Results:**
  - Muting stops audio capture and sets participant state to muted on all screens.
  - Deafening mutes microphone and silences all room audio output.
- **Automated Verification:** `flutter test test/features/community/presentation/widgets/voice_control_bar_test.dart`

---

### COM-17: Hand-Raise & Host Moderation
- **Preconditions:** In a large study room with Host permissions.
- **Step-by-Step Test Steps:**
  1. Participant taps **"Raise Hand"**.
  2. Host sees notification and taps **"Allow to Speak"**.
  3. Host taps **"Mute Participant"**.
- **Expected Results:**
  - Hand raise badge appears on participant avatar.
  - Host moderation commands enforce state on participant immediately.
- **Automated Verification:** `flutter test test/features/community/presentation/widgets/hand_raise_badge_test.dart`

---

### COM-18: Low-Data Mode for Audio Rooms
- **Preconditions:** In Live Room Settings.
- **Step-by-Step Test Steps:**
  1. Toggle **"Low-Data Saver Mode"**.
- **Expected Results:**
  - Clamps audio codec bitrate to Opus 16kbps mono, minimizing cellular data consumption by $>65\%$.
- **Automated Verification:** `flutter test test/features/community/data/services/livekit_audio_service_impl_test.dart`

---

## Module 8: Exam Timetable & Cram Workload Planner

### PLN-01: Exam Schedule & Venue Manager
- **Preconditions:** Timetable tab open.
- **Step-by-Step Test Steps:**
  1. Tap **"Add Exam Event"**.
  2. Enter: Course Code (`MTH 101`), Title (`Calculus I`), Venue (`Hall B`), Date (`Nov 15, 2026`), Time (`09:00 AM`), Target Grade (`A / 5.0`).
  3. Tap **"Save Exam"**.
- **Expected Results:**
  - Event persists in Drift SQLite `exam_events` table and appears chronologically in the timetable schedule list.
- **Automated Verification:** `flutter test test/features/planner/presentation/widgets/add_exam_modal_sheet_test.dart`

---

### PLN-02: Dynamic Urgency Countdown Banners
- **Preconditions:** Exam scheduled 3 days in the future.
- **Step-by-Step Test Steps:**
  1. View Timetable / Dashboard header.
  2. Observe countdown banner.
- **Expected Results:**
  - Displays color-coded urgency status:
    - $>14$ days: Calm Blue
    - $4–14$ days: Warning Amber
    - $\le 3$ days: Urgent Red Pulse (`"3 Days until MTH 101 Exam!"`)
- **Automated Verification:** `flutter test test/features/planner/presentation/widgets/exam_countdown_banner_test.dart`

---

### PLN-03: Adaptive Daily Cram Workload Engine
- **Preconditions:** Deck with 300 unlearned cards linked to an exam in 10 days with a $90\%$ retention target.
- **Step-by-Step Test Steps:**
  1. Inspect calculated daily review quota in planner.
- **Expected Results:**
  - Workload engine calculates exact cards per day: $\text{Daily Quota} = \frac{\text{Total Cards}}{\text{Days}} + \text{Projected FSRS Reviews}$.
- **Automated Verification:** `flutter test test/features/planner/domain/services/cram_workload_calculator_test.dart`

---

### PLN-04: Burnout & Overload Warning Banner
- **Preconditions:** User schedules 5 exams in 2 days or daily quota exceeds 300 cards/day.
- **Step-by-Step Test Steps:**
  1. View Planner workload summary.
- **Expected Results:**
  - High-yield safety banner displays: *"⚠️ High Overload Risk: Daily quota exceeds 300 cards. Kortex recommends prioritizing High-Yield decks to prevent cognitive fatigue."*
- **Automated Verification:** `flutter test test/features/planner/domain/services/cram_workload_calculator_test.dart`

---

### PLN-05: Study Calibration Intensity Heatmap
- **Preconditions:** User has study activity logged over past 30 days.
- **Step-by-Step Test Steps:**
  1. Open Planner Analytics tab.
  2. Inspect calendar activity heatmap.
- **Expected Results:**
  - 7-column calendar matrix displays color intensity boxes (0 cards = grey, 1-25 = light green, 26-75 = medium green, 75+ = dark green).
  - Tapping a day box displays exact review count and accuracy.
- **Automated Verification:** `flutter test test/features/planner/presentation/widgets/study_calibration_graph_widget_test.dart`

---

### PLN-06: Timetable Push Notification Reminders
- **Preconditions:** Exam scheduled for tomorrow at 09:00 AM.
- **Step-by-Step Test Steps:**
  1. Check scheduled local notifications via `NotificationService`.
- **Expected Results:**
  - Local notifications are queued for $T-24\text{ hours}$ and $T-1\text{ hour}$ with exam title, venue, and motivational review CTA.
- **Automated Verification:** `flutter test test/features/planner/presentation/services/notification_service_test.dart`

---

### PLN-07: Syllabus Topic Progress Checklists
- **Preconditions:** Course syllabus loaded into planner.
- **Step-by-Step Test Steps:**
  1. Open Syllabus Checklist for "JAMB Biology".
  2. Check off 3 completed topics (e.g., "Cell Structure", "Genetics", "Ecology").
- **Expected Results:**
  - Topic progress bar updates (e.g. "3/12 Topics Mastered (25%)").
  - State persists in SQLite database.
- **Automated Verification:** `flutter test test/features/planner/presentation/widgets/syllabus_checklist_widget_test.dart`

---

### PLN-08: Offline Timetable SQLite Storage
- **Preconditions:** Airplane Mode enabled.
- **Step-by-Step Test Steps:**
  1. Create, edit, and delete exam events while completely offline.
  2. Restart app while offline.
- **Expected Results:**
  - All timetable edits persist across restarts without loss.
- **Automated Verification:** `flutter test test/features/planner/data/datasources/exam_events_dao_test.dart`

---

## Module 9: ADHD & Neurodivergent Accessibility Suite

### ACC-01: Bionic Reading Text Engine
- **Preconditions:** Flashcard study, syllabus notes, or quiz explanations open.
- **Step-by-Step Test Steps:**
  1. Toggle **"Bionic Reading"** switch in Accessibility settings.
  2. Inspect text rendering across the app.
- **Expected Results:**
  - Initial letters of words are bolded to guide visual fixation points.
  - Works accurately on complex terms (e.g., "**Photosyn**thesis").
- **Automated Verification:** `flutter test test/shared/utils/bionic_text_formatter_test.dart`

---

### ACC-02: OLED Dark & High-Contrast Themes
- **Preconditions:** Appearance Settings open.
- **Step-by-Step Test Steps:**
  1. Cycle through themes: **Deep Space OLED (Pure Black #000000)**, **Warm Amber (Low Blue-Light)**, **Nordic Dusk**, **Clean Slate**.
- **Expected Results:**
  - All backgrounds, cards, typography, and contrast borders update seamlessly without app reload.
  - WCAG AAA contrast compliance on OLED Dark.
- **Automated Verification:** `flutter test test/features/theme/presentation/cubit/theme_cubit_test.dart`

---

### ACC-03: Reduced Motion & Sensory Toggle
- **Preconditions:** Accessibility Settings.
- **Step-by-Step Test Steps:**
  1. Turn on **"Reduced Motion & Low Sensory Mode"**.
  2. Navigate between tabs, flip flashcards, and finish a quiz.
- **Expected Results:**
  - Disables all particle confetti, floating emoji overlays, 3D flip card transforms, and parallax mesh shaders.
  - Replaces all animations with instant cuts or gentle opacity cross-fades.
- **Automated Verification:** `flutter test test/shared/theme/app_theme_test.dart`

---

### ACC-04: Dyslexia-Friendly OpenSans/Atkinson Fonts
- **Preconditions:** Typography settings.
- **Step-by-Step Test Steps:**
  1. Select **"Atkinson Hyperlegible"** or **"OpenDyslexic"** font family.
- **Expected Results:**
  - All UI elements, flashcards, questions, and chat messages re-render with the chosen dyslexia-optimized font.
- **Automated Verification:** `flutter test test/shared/theme/typography_config_test.dart`

---

### ACC-05: Haptic Micro-Feedback Loops
- **Preconditions:** Device with haptic motor enabled.
- **Step-by-Step Test Steps:**
  1. Tap FSRS grading buttons (Again, Hard, Good, Easy).
  2. Select MCQ answer in CBT practice.
  3. Drag and snap floating drawer.
- **Expected Results:**
  - Distinct subtle tactile vibration triggers for each action (e.g. Light impact for selection, Heavy double-click for milestone).
- **Automated Verification:** `flutter test test/shared/services/haptic_feedback_service_test.dart`

---

### ACC-06: Micro-Milestone Particle Celebrations
- **Preconditions:** Reduced motion disabled.
- **Step-by-Step Test Steps:**
  1. Complete a 10-card deck or maintain a 7-day streak.
- **Expected Results:**
  - Colorful confetti particle explosion appears for 2.5 seconds and auto-dismisses.
- **Automated Verification:** `flutter test test/shared/widgets/confetti_overlay_test.dart`

---

### ACC-07: Thought Parking Lot Drawer
- **Preconditions:** Accessible from anywhere in the app via quick gesture or header button.
- **Step-by-Step Test Steps:**
  1. Open Thought Parking Lot.
  2. Enter quick note: *"Look up definition of Gibbs Free Energy later"*.
  3. Tap **"Park Thought"**.
- **Expected Results:**
  - Instantly saves and clears input without interrupting active task.
- **Automated Verification:** `flutter test test/features/flashcards/presentation/widgets/thought_parking_lot_sheet_test.dart`

---

### ACC-08: Eye Rest & Movement Break Prompts
- **Preconditions:** Continuous study session running $>20\text{ minutes}$.
- **Step-by-Step Test Steps:**
  1. Keep focus session active for 20 minutes.
- **Expected Results:**
  - Non-intrusive 20-20-20 rule reminder banner pops up: *"👀 Time for an Eye Rest! Look at an object 20 feet away for 20 seconds."*
- **Automated Verification:** `flutter test test/features/focus/presentation/services/break_reminder_service_test.dart`

---

### ACC-09: Full WCAG 2.1 AA Semantics & Screen Reader
- **Preconditions:** TalkBack (Android) / VoiceOver (iOS) enabled.
- **Step-by-Step Test Steps:**
  1. Navigate across all 12 modules using screen reader gestures only.
- **Expected Results:**
  - Every button, input field, avatar, card, and icon has descriptive accessibility semantics.
  - Zero unlabelled icon buttons (e.g., "Button 42").
- **Automated Verification:** `flutter test test/shared/widgets/semantics_audit_test.dart`

---

### ACC-10: Audio Speed & Pitch Fine-Tuning
- **Preconditions:** TTS Audio Settings.
- **Step-by-Step Test Steps:**
  1. Adjust TTS Speed slider from $0.75\times$ to $2.0\times$.
  2. Play audio pronunciation or Syllabot voice response.
- **Expected Results:**
  - Audio playback speed adjusts smoothly in real time without audio distortion or pitch glitches.
- **Automated Verification:** `flutter test test/shared/services/tts_config_test.dart`

---

## Module 10: Profile, Security & Two-Factor Authentication

### SEC-01: TOTP Two-Factor Authenticator Setup
- **Preconditions:** User in Security Settings.
- **Step-by-Step Test Steps:**
  1. Tap **"Enable Two-Factor Authentication (TOTP)"**.
  2. Scan displayed QR code with Google Authenticator or copy secret key.
  3. Enter 6-digit TOTP code from authenticator app.
  4. Tap **"Verify & Activate"**.
- **Expected Results:**
  - TOTP key validates; 2FA status toggles to "Enabled".
  - Subsequent logins require valid 6-digit code.
- **Edge Cases:**
  - Entering invalid/expired 6-digit code: Displays error toast ("Invalid code, please try again").
- **Automated Verification:** `flutter test test/features/security/presentation/pages/two_factor_setup_page_test.dart`

---

### SEC-02: MFA Backup Codes Recovery
- **Preconditions:** 2FA enabled.
- **Step-by-Step Test Steps:**
  1. View generated 10 single-use backup recovery codes.
  2. Tap **"Copy All Codes"** or **"Download PDF"**.
  3. Use one backup code during login in place of TOTP code.
- **Expected Results:**
  - Login succeeds with backup code; used backup code is permanently marked as redeemed.
- **Automated Verification:** `flutter test test/features/security/presentation/pages/security_settings_page_test.dart`

---

### SEC-03: Biometric App Lock (FaceID / Fingerprint)
- **Preconditions:** Device has biometric authentication registered (FaceID / Fingerprint).
- **Step-by-Step Test Steps:**
  1. Enable **"Biometric App Lock"** in Security Settings.
  2. Send Kortex app to background for 5 seconds.
  3. Reopen Kortex.
- **Expected Results:**
  - Full-screen biometric lock overlay appears immediately, obscuring sensitive study data.
  - Successfully authenticating with FaceID/Fingerprint unlocks app.
- **Edge Cases:**
  - 3 failed biometric attempts: Prompts for device PIN/passcode fallback.
- **Automated Verification:** `flutter test test/features/security/presentation/services/biometric_auth_service_test.dart`

---

### SEC-04: Dynamic Academic Track Switcher
- **Preconditions:** User profile open.
- **Step-by-Step Test Steps:**
  1. Tap **"Academic Track & Focus"**.
  2. Switch from "High School (JAMB Science)" to "Higher Ed (Computer Science 300L)".
  3. Confirm track switch.
- **Expected Results:**
  - Dashboard feed, auto-communities, question bank, and Syllabot context update to match new track immediately.
- **Automated Verification:** `flutter test test/features/profile/presentation/pages/academic_track_settings_page_test.dart`

---

### SEC-05: Syllabot AI Persona Tuning
- **Preconditions:** Profile Settings -> AI Settings.
- **Step-by-Step Test Steps:**
  1. Change AI Persona to "Concise Summary Mode".
  2. Change AI Creativity Temperature slider to 0.2.
- **Expected Results:**
  - Settings persist in profile and apply to all new Syllabot conversations.
- **Automated Verification:** `flutter test test/features/profile/presentation/pages/syllabot_ai_settings_page_test.dart`

---

### SEC-06: Avatar & Profile Customization
- **Preconditions:** Profile Page open.
- **Step-by-Step Test Steps:**
  1. Tap avatar to open Avatar Picker modal.
  2. Choose a new avatar or upload photo.
  3. Edit Display Name and Bio.
  4. Tap **"Save Profile"**.
- **Expected Results:**
  - Avatar and name update across Dashboard, Community Rooms, and Leaderboards.
- **Automated Verification:** `flutter test test/features/profile/presentation/pages/profile_page_test.dart`

---

### SEC-07: Data Export & Account Deletion (GDPR)
- **Preconditions:** Account Settings open.
- **Step-by-Step Test Steps:**
  1. Tap **"Export All My Data"** -> Generates and downloads full JSON zip archive of all decks, review logs, and notes.
  2. Tap **"Delete Account"** -> Type confirmation phrase "DELETE".
  3. Tap **"Permanently Purge Account"**.
- **Expected Results:**
  - User account, remote Supabase records, and local Drift database tables are wiped cleanly; app redirects to Splash/Onboarding.
- **Automated Verification:** `flutter test test/features/profile/presentation/pages/account_settings_page_test.dart`

---

### SEC-08: Device Session Manager
- **Preconditions:** User logged in on multiple devices (e.g. Phone + Tablet).
- **Step-by-Step Test Steps:**
  1. Open **"Active Sessions"** list.
  2. Verify list shows current device, secondary device, IP location, and last active time.
  3. Tap **"Revoke Session"** on the secondary device.
- **Expected Results:**
  - Secondary device receives token revocation and is automatically logged out upon next network request.
- **Automated Verification:** `flutter test test/features/security/presentation/widgets/active_sessions_list_widget_test.dart`

---

### SEC-09: Local Storage Encryption (SQLCipher)
- **Preconditions:** Rooted / Jailbroken test environment or file inspector.
- **Step-by-Step Test Steps:**
  1. Inspect local SQLite database file (`kortex.sqlite`) directly via hex editor / raw SQLite tool.
- **Expected Results:**
  - Database file is fully encrypted with 256-bit AES SQLCipher; reading without hardware keystore key fails with `file is not a database` error.
- **Automated Verification:** `flutter test test/core/database/encrypted_database_test.dart`

---

## Module 11: Monetization, RevenueCat & Subscription Guards

### MON-01: RevenueCat SDK Integration
- **Preconditions:** In-App Purchase sandbox / StoreKit testing configuration active.
- **Step-by-Step Test Steps:**
  1. Launch app with RevenueCat initialized.
  2. Query available subscription offerings (Monthly Pro, Annual Pro with 7-Day Trial).
- **Expected Results:**
  - Offerings return valid localized prices and product IDs from App Store / Google Play sandbox.
- **Automated Verification:** `flutter test test/features/monetization/data/services/revenue_cat_service_test.dart`

---

### MON-02: Feature Paywall Screen
- **Preconditions:** Free tier user triggers Pro feature.
- **Step-by-Step Test Steps:**
  1. Tap a Pro feature (e.g., Unlimited AI Document Ingestion).
  2. Observe Paywall modal screen.
  3. Tap **"Subscribe Annual (7 Days Free)"**.
  4. Complete sandbox purchase.
- **Expected Results:**
  - Modal displays feature comparison table and trial terms clearly.
  - Completing purchase unlocks Pro features immediately and dismisses paywall.
- **Automated Verification:** `flutter test test/features/monetization/presentation/pages/paywall_screen_test.dart`

---

### MON-03: Granular Subscription Feature Guards
- **Preconditions:** User is on Free tier.
- **Step-by-Step Test Steps:**
  1. Attempt to upload a 6th document in a month (exceeding free limit of 5).
  2. Attempt to stay in Live Voice Room $>45\text{ minutes}$.
- **Expected Results:**
  - `SubscriptionGuard` intercepts action before API call and presents Upgrade to Pro modal.
- **Automated Verification:** `flutter test test/features/monetization/presentation/guards/subscription_guard_test.dart`

---

### MON-04: Free Tier Daily Quota Counter
- **Preconditions:** Free tier user.
- **Step-by-Step Test Steps:**
  1. Send 20 Syllabot AI chat messages in one calendar day.
  2. Send message 21.
- **Expected Results:**
  - Message 21 displays quota reached banner: *"You've used your 20 free daily AI queries. Upgrade to Pro for unlimited queries or wait until midnight."*
- **Automated Verification:** `flutter test test/features/monetization/data/services/quota_manager_service_test.dart`

---

### MON-05: Offline Entitlement Grace Period
- **Preconditions:** Active Pro subscriber goes into 100% Airplane Mode.
- **Step-by-Step Test Steps:**
  1. Keep device offline for 3 days.
  2. Access Pro features (Unlimited flashcards, local AI inference).
  3. Keep device offline for $>8\text{ days}$ (exceeding 7-day grace period).
- **Expected Results:**
  - Days 1–7: All Pro features remain fully unlocked via cached entitlement.
  - Day 8+: Prompts user to connect to internet once to verify active subscription.
- **Automated Verification:** `flutter test test/features/monetization/data/services/subscription_cache_service_test.dart`

---

### MON-06: Promotional Code & Voucher Redemption
- **Preconditions:** Redeem promo code sheet open.
- **Step-by-Step Test Steps:**
  1. Enter valid promo code (e.g., `SCHOLARSHIP2026`).
  2. Tap **"Redeem Code"**.
  3. Attempt to enter already used or invalid code (`FAKEXYZ`).
- **Expected Results:**
  - Valid code applies Pro access entitlement for specified duration (e.g., 6 months).
  - Invalid code displays clear error ("Invalid or expired promotional code").
- **Automated Verification:** `flutter test test/features/monetization/presentation/widgets/promo_code_bottom_sheet_test.dart`

---

## Module 12: Offline-First Architecture & Core Infrastructure

### INF-01: Drift SQLite Database Engine
- **Preconditions:** Local database initialized.
- **Step-by-Step Test Steps:**
  1. Run CRUD operations on all tables (`decks`, `cards`, `review_logs`, `exam_events`, `past_questions`, `thought_parking_lot`).
  2. Verify foreign key cascade deletions (Deleting a deck deletes all its associated cards).
- **Expected Results:**
  - All relational queries execute with zero constraint violations.
- **Automated Verification:** `flutter test test/core/database/app_database_test.dart`

---

### INF-02: Background Card Sync Queue
- **Preconditions:** Device in Airplane Mode.
- **Step-by-Step Test Steps:**
  1. Review 15 flashcards offline.
  2. Add 2 new flashcards offline.
  3. Inspect SQLite `sync_queue` table.
  4. Turn off Airplane Mode (Reconnect to internet).
- **Expected Results:**
  - All 17 mutations are enqueued locally.
  - Upon reconnection, `CardSyncQueue` drains and pushes events to Supabase in background without blocking UI.
- **Automated Verification:** `flutter test test/features/flashcards/data/datasources/card_sync_queue_test.dart`

---

### INF-03: Exponential Backoff Network Retry
- **Preconditions:** Simulated flaky server (returns HTTP 503 or dropped packets).
- **Step-by-Step Test Steps:**
  1. Trigger sync request.
  2. Inspect network logs for retry intervals.
- **Expected Results:**
  - Retries at jittered intervals: $1\text{s} \to 2\text{s} \to 4\text{s} \to 8\text{s}$ up to max attempts, then pauses to avoid battery drain.
- **Automated Verification:** `flutter test test/core/network/dio_interceptors_test.dart`

---

### INF-04: Dio Interceptors & Token Refresh
- **Preconditions:** Expired access token with valid refresh token.
- **Step-by-Step Test Steps:**
  1. Send authenticated API request.
  2. Intercept HTTP 401 response.
- **Expected Results:**
  - Dio interceptor pauses outgoing requests, calls refresh token endpoint, updates secure storage, and retries the original failed request seamlessly.
- **Automated Verification:** `flutter test test/core/network/auth_token_manager_test.dart`

---

### INF-05: Session Expiration Handler
- **Preconditions:** Both access token and refresh token revoked/expired.
- **Step-by-Step Test Steps:**
  1. Trigger API request.
- **Expected Results:**
  - Displays non-destructive session expired modal asking user to re-enter password/biometrics without wiping local offline database.
- **Automated Verification:** `flutter test test/core/services/session_expired_service_test.dart`

---

### INF-06: Crashlytics & Telemetry Service
- **Preconditions:** Test environment with Crashlytics enabled.
- **Step-by-Step Test Steps:**
  1. Trigger handled exception and test uncaught error boundary.
- **Expected Results:**
  - Error is caught cleanly, user sees friendly fallback UI, and sanitized stack trace is reported to Crashlytics dashboard with breadcrumbs.
- **Automated Verification:** `flutter test test/core/services/crashlytics_service_test.dart`

---

### INF-07: Performance Trace & Frame Watcher
- **Preconditions:** Profile/Release build running on test device.
- **Step-by-Step Test Steps:**
  1. Rapidly scroll 1000-card deck list and execute heavy search filters.
- **Expected Results:**
  - Frame rendering time stays below $16.6\text{ms}$ (60 FPS).
  - Any frame drops $>100\text{ms}$ log a performance trace alert.
- **Automated Verification:** `flutter test test/core/services/performance_service_test.dart`

---

### INF-08: SSL Certificate Pinning
- **Preconditions:** Proxy tool (Charles / Proxyman / mitmproxy) installed with custom root cert.
- **Step-by-Step Test Steps:**
  1. Route device traffic through intercepting proxy.
  2. Attempt to make API requests to Kortex Supabase / Backend.
- **Expected Results:**
  - TLS handshake fails immediately with `CERTIFICATE_VERIFY_FAILED`.
  - Zero plain-text data or authentication tokens leak to proxy.
- **Automated Verification:** `flutter test test/core/network/http_override_verified_cert_test.dart`

---

### INF-09: Background Push Notification Handler
- **Preconditions:** App in terminated/killed state.
- **Step-by-Step Test Steps:**
  1. Send test FCM push notification payload (Study reminder or Study Circle invite).
  2. Tap on notification on device lock screen.
- **Expected Results:**
  - App cold launches and routes directly to the relevant deck or study circle room.
- **Automated Verification:** `flutter test test/core/notifications/fcm_notification_handler_test.dart`

---

### INF-10: Zero-Allocation Math Parser Cache
- **Preconditions:** Card list with repeated KaTeX mathematical expressions.
- **Step-by-Step Test Steps:**
  1. Rapidly render 100 math cards.
- **Expected Results:**
  - Parsed AST syntax trees are retrieved from LRU memoization cache in $<1\text{ms}$ with zero duplicate memory allocations.
- **Automated Verification:** `flutter test test/features/flashcards/presentation/widgets/latex_card_content_viewer_test.dart`

---

### INF-11: Clean Architecture Dependency Injection
- **Preconditions:** App initialization.
- **Step-by-Step Test Steps:**
  1. Execute DI registration test suite (`GetIt`).
- **Expected Results:**
  - All singletons, factories, BLoCs, and repositories resolve with zero circular dependency loops or missing registration errors.
- **Automated Verification:** `flutter test test/injection_container_test.dart`

---

## 14. Automated Test Suite Execution Matrix

To run all automated validations and verify regression safety across the entire product suite:

```bash
# 1. Run all Unit & Repository tests
flutter test test/core/
flutter test test/features/

# 2. Run all Widget & Presentation tests
flutter test test/features/**/presentation/

# 3. Run all Sprint & Feature Integration suites
flutter test test/features/sprint_two_feature_widgets_test.dart

# 4. Generate Code Coverage Report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

> **QA Sign-Off Protocol:**  
> Before any release candidate (RC) build is promoted to App Store / Google Play production tracks:
> 1. 100% of P0 & P1 test cases in this validation guide must pass.
> 2. Zero open Blocker (S1) or Critical (S2) defects.
> 3. Full offline regression suite executed on low-spec Android and iOS physical devices.
