# Kortex EdTech Platform — Comprehensive Feature Audit & Production-Readiness Roadmap

> **Audit Context & Scope:**  
> **Executive Role:** Senior Project Manager, Lead QA Specialist, and Principal EdTech UI/UX Architect.  
> **Target Scope:** 100% recursive audit of all 18 functional feature modules under `lib/src/features/**`.  
> **Primary Objective:** Eliminate all mock data, local JSON stubs, fake `Future.delayed()` calls, and fallback data structures to achieve 100% Backend Production-Readiness, bulletproof QA operations, and optimized Product-Market Fit (PMF).

---

## 1. Executive Summary & Production Readiness Matrix

| Feature | Current State | PMF Readiness | Mock Data Status | Primary Backend Blocker | Priority |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1. Auth (`auth`)** | Partial API integration with Supabase Auth; reset password UI uses fake timer. | High | Partial | Missing Auth Recovery API endpoint integration (`/auth/v1/recover`) and course track fallback purge. | **P0** |
| **2. Community (`community`)** | REST & Realtime thread tree working; fallback static rooms and local heuristic sort active. | High | Partial | Missing Realtime study room discovery API and server-side vector knowledge-gap recommendation endpoint. | **P0** |
| **3. Dashboard (`dashboard`)** | Main student hub; fallback static course catalog and locally generated analytics active. | High | Partial | Missing server-aggregated analytics endpoint (`/rest/v1/rpc/get_dashboard_analytics`) & live course catalog sync. | **P0** |
| **4. Deck Marketplace (`deck_marketplace`)** | Shared deck discovery & cloning via `CommunityRepository`; fallback static JSON decks when offline. | Medium | Partial | Missing Supabase Marketplace search index, rating/download aggregation RPC, and monetization lock API. | **P1** |
| **5. Decks (`decks`)** | Full FSRS-6 spaced repetition, Drift SQLite offline DB & Supabase sync; retry queue needed. | High | Live | Missing resilient background offline card sync queue worker and multi-device conflict resolution protocol. | **P0** |
| **6. Ingestion (`ingestion`)** | Local MLKit OCR & PDF parser working; LMS import uses hardcoded demo OAuth tokens. | High | Hardcoded | Missing OAuth2 proxy server for Google Classroom API & Canvas LMS token exchange endpoints. | **P0** |
| **7. Leaderboard (`leaderboard`)** | Realtime table streaming XP & streaks; missing server-side cron reset & verification. | Medium | Live | Missing automated weekly XP reset cron job and anti-cheat verification backend guard. | **P1** |
| **8. Monetization (`monetization`)** | RevenueCat SDK integration present; placeholder keys present in code fallback. | High | Hardcoded | Missing production RevenueCat API key environment configuration & server Webhook entitlement listener. | **P0** |
| **9. Notifications (`notifications`)** | Local inbox & Supabase REST fetch working; FCM push token registration is stubbed. | Medium | Partial | Missing FCM device token registration API (`/rest/v1/user_device_tokens`) & push dispatch worker. | **P1** |
| **10. Offline AI (`offline_ai`)** | Isolate manager with RAM profile allocation; model binary CDN fetch is stubbed. | Medium | Partial | Missing CDN model binary distribution server & GGUF model manifest versioning API. | **P2** |
| **11. Onboarding (`onboarding`)** | Page-view carousel & rocket animation; profile sync missing server confirmation. | High | Live | Missing onboarding state flag synchronization endpoint to `user_profiles` database table. | **P0** |
| **12. Onboarding Calibration (`onboarding_calibration`)** | Multi-step curriculum setup; 400+ lines of fallback static metadata used on network failure. | High | Partial | Missing centralized curriculum metadata REST API (`/rest/v1/curriculum_metadata`) endpoint. | **P0** |
| **13. Onboarding Utility (`onboarding_utility`)** | UI helper utilities and step management logic. | Low | Live | N/A — Pure presentation helper module. | **P2** |
| **14. Planner (`planner`)** | Cram workload calculator, Drift DB, Supabase REST CRUD; schema mismatch fallbacks present. | High | Live | Missing database schema migration alignment for `exam_events` (`assessment_type`, `scoped_deck_ids`). | **P0** |
| **15. Profile (`profile`)** | Profile edit, avatar upload, and MFA factor management; session revocation incomplete. | Medium | Live | Missing active sessions revocation API endpoint (`/auth/v1/admin/users/{id}/factors`) & TOTP QR generator. | **P1** |
| **16. Quiz (`quiz`)** | CBT exam simulator & 1v1 Quiz Duel; fallback default hardcoded questions used in duels. | High | Partial | Missing dynamic quiz duel question pool generator RPC and WebSocket matchmaking queue worker. | **P0** |
| **17. Study Rooms (`study_rooms`)** | LiveKit WebRTC audio & Supabase Realtime presence; room audio recording is stubbed. | High | Partial | Missing LiveKit room token generator backend service & cloud audio session recording pipeline. | **P1** |
| **18. Syllabot (`syllabot`)** | Multi-engine Socratic RAG chat; voice input button uses `Future.delayed` stub. | High | Partial | Missing Realtime Speech-To-Text (Whisper / Gemini Audio STT) streaming WebSocket/REST endpoint. | **P0** |

---

## 2. Feature-by-Feature Audits

---

### Feature 1: Authentication & Identity (`auth`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** Password recovery friction or sign-up failures cause immediate user churn at top-of-funnel onboarding. If course track selection fails to persist, personal exam targets are lost.
* **QA Operations:** `ForgotPasswordPage` uses a fake timer that pops the route without verifying email existence or firing an actual password reset email.
* **UI/UX Architect:** Tap state on submit buttons lacks optimistic loading lockouts, leading to multi-tap payload duplication.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/auth/presentation/pages/forgot_password_page.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/auth/presentation/pages/forgot_password_page.dart#L25-L32)
  * **Current Mock Behavior:** Executes `Future.delayed(Duration(seconds: 1))` and pops navigation route immediately.
  * **Required Backend Integration:** Wire to `AuthBloc` -> `ResetPasswordUseCase` -> `POST /auth/v1/recover`.
  * **Loading & Error States:** Display inline loader in `AppButton`, show success banner on HTTP 200, and render actionable error message on invalid email.
* **Location:** [`lib/src/features/auth/data/data_sources/auth_remote_data_source_impl.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/auth/data/data_sources/auth_remote_data_source_impl.dart#L150-L203)
  * **Current Mock Behavior:** Returns 7 hardcoded `CourseTrackModel` instances (WAEC, JAMB, Sciences, Medicine, Engineering, Law, General) when `fetchCourseTracks()` fails.
  * **Required Backend Integration:** `GET /rest/v1/course_tracks?select=*` with HTTP cache headers.
  * **Loading & Error States:** Shimmer placeholder card list during fetch; retry snackbar on failure instead of silent dummy fallback.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Connect `ForgotPasswordPage` to Supabase recovery API; enforce strict server validation on email format.
* **P1 UX & Habit Loop:** Implement auto-login session persistence check on app resume with seamless background token refresh.
* **P2 Scale:** Add biometric auth (FaceID / TouchID) integration into `AuthRouteGuard`.

---

### Feature 2: Community Hub & Discussion Forums (`community`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** Peer discussions build network effects. If study room list or forum feed drops to static curated fallbacks on poor connection, user engagement stalls.
* **QA Operations:** Local preferences (`forum_bookmarked_post_ids`, `forum_subscribed_post_ids`) can get out of sync with Supabase backend database when toggling offline.
* **UI/UX Architect:** Thread detail page loading lacks structured reply depth shimmers, leading to layout jumps.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/community/data/data_sources/community_remote_data_source_impl.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/community/data/data_sources/community_remote_data_source_impl.dart#L123)
  * **Current Mock Behavior:** `fetchStudyRooms()` invokes `_getCuratedFallbackRooms()` on network failure.
  * **Required Backend Integration:** `GET /rest/v1/study_rooms?select=*&order=created_at.desc`.
  * **Loading & Error States:** `CommunityHubShimmer` widget with pull-to-refresh failover.
* **Location:** [`lib/src/features/community/data/data_sources/community_remote_data_source_impl.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/community/data/data_sources/community_remote_data_source_impl.dart#L302-L333)
  * **Current Mock Behavior:** Knowledge gap sorting runs client-side text heuristic filtering.
  * **Required Backend Integration:** `POST /rest/v1/rpc/fetch_knowledge_gap_posts` backed by pgvector embeddings.
  * **Loading & Error States:** Display animated topic cluster shimmer while vector similarity calculation finishes.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Replace client-side thread filtering with keyset pagination RPC (`fetch_forum_posts_keyset`); enforce server-side thread deduplication.
* **P1 UX & Habit Loop:** Add push notifications for forum upvotes and verified Socratic answer solutions.
* **P2 Scale:** Integrate automated AI content moderation service prior to post insertion.

---

### Feature 3: Executive Student Dashboard (`dashboard`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** The dashboard is the daily habit anchor. Displaying static default catalog courses ('course_waec_math', etc.) disconnects the student from their specific university or exam goals.
* **QA Operations:** CBT readiness calculation relies on local activity logs that reset if local preferences are cleared.
* **UI/UX Architect:** Analytics charts drop data points abruptly if summary endpoint returns partial records.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/dashboard/data/data_sources/dashboard_remote_data_source_impl.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/dashboard/data/data_sources/dashboard_remote_data_source_impl.dart#L103-L178)
  * **Current Mock Behavior:** Generates default catalog courses from hardcoded static subject list when calibration profile is missing.
  * **Required Backend Integration:** `GET /rest/v1/user_courses?select=*,courses(*)` linked to authenticated `user_id`.
  * **Loading & Error States:** Skeleton course cards carousel; empty state prompting curriculum setup.
* **Location:** [`lib/src/features/dashboard/data/data_sources/dashboard_remote_data_source_impl.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/dashboard/data/data_sources/dashboard_remote_data_source_impl.dart#L300-L350)
  * **Current Mock Behavior:** Mock analytics summary generated on network exception.
  * **Required Backend Integration:** `GET /rest/v1/rpc/get_dashboard_analytics_summary`.
  * **Loading & Error States:** Ebbinghaus retention curve shimmer loader.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Unify dashboard feed loading under `GetDashboardFeedUseCase` with live database views.
* **P1 UX & Habit Loop:** Implement dynamic streak heatmaps and CBT readiness score progress gauge.
* **P2 Scale:** Add real-time peer study activity feed overlay.

---

### Feature 4: Deck Marketplace (`deck_marketplace`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** High-quality shared decks reduce activation friction. If shared decks fall back to static local JSON, user-generated content growth stalls.
* **QA Operations:** Cloning shared decks creates orphaned card records if foreign key cascade rules fail on server.
* **UI/UX Architect:** Marketplace card preview lacks multi-line title truncation and subject tag overflow handling.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/community/data/data_sources/community_remote_data_source_impl.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/community/data/data_sources/community_remote_data_source_impl.dart#L1496)
  * **Current Mock Behavior:** `_getCuratedFallbackSharedDecks()` returns static deck models when fetch fails.
  * **Required Backend Integration:** `GET /rest/v1/shared_decks?select=*&order=downloads_count.desc`.
  * **Loading & Error States:** Grid tile shimmer; retry button with offline indication.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Connect deck publishing modal sheet to `POST /rest/v1/shared_decks` and bulk card payload RPC.
* **P1 UX & Habit Loop:** Implement deck ratings, creator profiles, and bookmarking.
* **P2 Scale:** Add monetized premium deck tiers with RevenueCat entitlement checks.

---

### Feature 5: Flashcard Engine & Spaced Repetition (`decks`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** FSRS-6 algorithm guarantees long-term retention. Unsynced local card reviews lead to duplicate work across mobile and web.
* **QA Operations:** Local SQLite database (Drift) saves deck updates immediately, but failed remote HTTP payloads drop silently without entering a persistent retry queue.
* **UI/UX Architect:** Card flip animation can cause frame drops during complex LaTeX rendering.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/decks/data/data_sources/decks_remote_data_source_impl.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/decks/data/data_sources/decks_remote_data_source_impl.dart#L163-L210)
  * **Current Mock Behavior:** Catches error silently during `createDeckRecord` and `bulkInsertCards`, marking operations as "proceeding offline" without enqueueing network retry.
  * **Required Backend Integration:** Implement durable `CardSyncQueue` with exponential backoff against `POST /rest/v1/decks` and `POST /rest/v1/flashcards`.
  * **Loading & Error States:** Sync indicator icon (synced / pending sync) on deck tiles.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Build background sync queue worker for offline FSRS rating updates (`POST /rest/v1/rpc/sync_flashcard_reviews`).
* **P1 UX & Habit Loop:** Add FSRS custom parameter tuning UI in Settings.
* **P2 Scale:** Implement vector similarity search for instant card duplication prevention during deck creation.

---

### Feature 6: Document Ingestion & Optical Character Recognition (`ingestion`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** Student uploads syllabus/lecture notes -> instant deck generation. Fake LMS tokens break confidence for university students.
* **QA Operations:** `LmsImportDataSourceImpl` contains hardcoded tokens (`token_google_classroom`, `canvas_access_token`, `demo`, `test`, `verified`) returning static mock course bundles.
* **UI/UX Architect:** Camera live scanner overlay lacks clear visual bounds for document edge detection.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/ingestion/data/data_sources/lms_import_data_source.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/ingestion/data/data_sources/lms_import_data_source.dart#L159-L238)
  * **Current Mock Behavior:** Returns `_getMockGoogleCourses()` and `_getMockCanvasCourses()` when demo or test tokens are detected.
  * **Required Backend Integration:** Secure OAuth2 backend proxy endpoints (`POST /api/v1/lms/google/token`, `POST /api/v1/lms/canvas/token`).
  * **Loading & Error States:** Progress bar showing step-by-step syllabus parsing and assignment extraction.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Replace hardcoded LMS token checks with production OAuth2 PKCE flow for Google Classroom and Canvas API.
* **P1 UX & Habit Loop:** Add support for audio lecture transcription ingestion via Whisper backend API.
* **P2 Scale:** Multi-file batch document ingestion with background queue processing.

---

### Feature 7: Leaderboards & Gamification (`leaderboard`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** Leaderboards drive competitive habit loops. Static or unverified XP values degrade trust.
* **QA Operations:** WebSocket listener updates local state broadcast without server-side signature verification.
* **UI/UX Architect:** Podium widget layout clips usernames longer than 14 characters on small screens.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/community/data/data_sources/community_remote_data_source_impl.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/community/data/data_sources/community_remote_data_source_impl.dart#L1553-L1601)
  * **Current Mock Behavior:** In-memory stream map sorting without server-verified anti-cheat validation.
  * **Required Backend Integration:** Realtime Postgres changes stream on `leaderboards` table + `POST /rest/v1/rpc/claim_weekly_xp`.
  * **Loading & Error States:** Podiums shimmer loader; error snackbar on connection drop.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Implement server-side Cron job for weekly XP resets and league promotions.
* **P1 UX & Habit Loop:** Add streak freeze shields and tier promotion celebration modals.
* **P2 Scale:** Region-based and university-department specific leaderboard filtering.

---

### Feature 8: Monetization & In-App Purchases (`monetization`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** Revenue conversion relies on seamless paywall execution. Placeholder keys fail purchases silently.
* **QA Operations:** `RevenueCatService` checks for placeholder API keys (`rcb_your_revenuecat_web_stripe_key`, `goog_your_play_console_key`, `appl_your_app_store_key`) and disables purchase execution.
* **UI/UX Architect:** Paywall screen lacks dynamic currency symbol formatting based on store locale.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/monetization/data/datasources/revenuecat_service.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/monetization/data/datasources/revenuecat_service.dart#L19-L22)
  * **Current Mock Behavior:** Uses static string fallbacks for API keys, causing configuration bypass.
  * **Required Backend Integration:** Inject production RevenueCat keys via secure `.env` build flags and integrate server Webhook entitlement sync (`POST /api/v1/webhooks/revenuecat`).
  * **Loading & Error States:** Paywall package selection shimmer; native platform purchase progress sheet.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Configure production StoreKit and Google Play Billing API keys; enable Stripe Web Billing for Web target.
* **P1 UX & Habit Loop:** Add localized pricing tables and promotional discount banner popups.
* **P2 Scale:** Server-side entitlement validation guard on all AI generation endpoints.

---

### Feature 9: Notifications & Reminders (`notifications`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** Re-engagement notifications drive daily study retention. Absent FCM token sync prevents out-of-app push retention.
* **QA Operations:** FCM push message listener receives payload but `markAsRead` relies on local state update before server patch confirms.
* **UI/UX Architect:** Notification inbox list tiles lack swipe-to-dismiss gesture feedback.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/notifications/presentation/bloc/notifications_cubit.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/notifications/presentation/bloc/notifications_cubit.dart#L175-L228)
  * **Current Mock Behavior:** Patches notification status directly via raw Dio without verifying device FCM token association.
  * **Required Backend Integration:** `POST /rest/v1/user_device_tokens` and `PATCH /rest/v1/notifications?id=eq.{id}`.
  * **Loading & Error States:** Inbox list shimmer loader; empty state illustration when inbox is empty.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Register FCM device token on user login and link to Supabase user profile.
* **P1 UX & Habit Loop:** Implement smart study reminder schedule based on user's peak retention hours.
* **P2 Scale:** Rich media push notifications with direct action buttons (e.g., "Start Review").

---

### Feature 10: On-Device & Offline AI Infrastructure (`offline_ai`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** Offline study capability allows uninterrupted learning in low-connectivity regions.
* **QA Operations:** `LocalInferenceIsolateManager` manages RAM allocations, but model binary downloading is hardcoded to expect local file paths without remote CDN download resilience.
* **UI/UX Architect:** Model download progress bar lacks detailed download speed (MB/s) indicator.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/offline_ai/data/services/local_inference_isolate_manager.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/offline_ai/data/services/local_inference_isolate_manager.dart#L34-L57)
  * **Current Mock Behavior:** Assumes static local GGUF model path availability.
  * **Required Backend Integration:** `GET /api/v1/models/manifest` and CDN range-request binary downloader service.
  * **Loading & Error States:** Downloading overlay with pause/resume controls and checksum verification.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Implement background GGUF model downloader with SHA256 integrity verification.
* **P1 UX & Habit Loop:** Add model size selection (TinyLlama 1.1B vs Gemma 2B) in app settings.
* **P2 Scale:** Multi-threaded CPU core allocation optimizer based on device thermal status.

---

### Feature 11: Student Onboarding Flow (`onboarding`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** Onboarding establishes user value proposition. If completion state fails to sync to backend, returning users re-trigger onboarding.
* **QA Operations:** Rocket launch animation triggers local preferences write without awaiting confirmation from user profile service.
* **UI/UX Architect:** Carousel transition speed on lower-end devices can jitter if images are uncompressed.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/onboarding/presentation/pages/onboarding_page.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/onboarding/presentation/pages/onboarding_page.dart)
  * **Current Mock Behavior:** Saves `is_onboarded` flag exclusively to local preferences (`SharedPreferences`).
  * **Required Backend Integration:** `PATCH /rest/v1/user_profiles?id=eq.{user_id}` with `{"is_onboarded": true}`.
  * **Loading & Error States:** Full-screen launch loader with seamless transition to Dashboard.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Synchronize onboarding completion state with Supabase user profile table.
* **P1 UX & Habit Loop:** Dynamic onboarding slides tailored to selected user track (High School vs Higher Ed).
* **P2 Scale:** A/B testing onboarding flow variations using Firebase Remote Config.

---

### Feature 12: Academic Track & Curriculum Calibration (`onboarding_calibration`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** Accurate curriculum calibration ensures tailored flashcard generation. Falling back to static hardcoded metadata limits non-standard tracks.
* **QA Operations:** `CurriculumRemoteDataSourceImpl` contains over 300 lines of hardcoded fallback arrays (`fallbackStandardizedExams`, `fallbackFacultyTracks`, etc.) used whenever REST calls return non-200.
* **UI/UX Architect:** Subject selection grid chips lack smooth multi-select animation states.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/onboarding_calibration/data/data_sources/curriculum_remote_data_source_impl.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/onboarding_calibration/data/data_sources/curriculum_remote_data_source_impl.dart#L139-L446)
  * **Current Mock Behavior:** Serves extensive static arrays for exams, tracks, and goals on network failure.
  * **Required Backend Integration:** `GET /rest/v1/curriculum_metadata?select=*` with local SQLite table caching.
  * **Loading & Error States:** Step tracker shimmer loaders; offline retry indicator.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Migrate curriculum metadata to backend database table and cache locally in Drift DB.
* **P1 UX & Habit Loop:** Allow custom institution and department search during university track calibration.
* **P2 Scale:** Dynamic exam countdown auto-configuration based on official university timetable API feed.

---

### Feature 13: Onboarding Utilities (`onboarding_utility`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** Ensures seamless step transitions during onboarding.
* **QA Operations:** Pure UI presentation helper module.
* **UI/UX Architect:** Needs consistent motion curves across all onboarding steps.

#### B. Mock & Dummy Data Purge Target List
* **Location:** `lib/src/features/onboarding_utility/`
  * **Current Mock Behavior:** Operates on local widget state.
  * **Required Backend Integration:** N/A.
  * **Loading & Error States:** N/A.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Audit accessibility tap targets across all helper widgets.
* **P1 UX & Habit Loop:** Standardize transition animations with `AppMotion` tokens.
* **P2 Scale:** Code refactoring and bundle size optimization.

---

### Feature 14: Exam Timetable & Cram Planner (`planner`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** Exam countdowns instill urgency and drive daily review targets. Schema mismatches break exam event persistence.
* **QA Operations:** `PlannerRepositoryImpl` falls back to legacy schema payload when Supabase returns HTTP 400 due to missing `assessment_type` column on backend.
* **UI/UX Architect:** Cram calibration graph lacks touch tooltip inspection for daily target projections.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/planner/data/repositories/planner_repository_impl.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/planner/data/repositories/planner_repository_impl.dart#L312-L338)
  * **Current Mock Behavior:** Retries failed payload with stripped fields when backend schema cache mismatch occurs.
  * **Required Backend Integration:** Execute database migration script to align `exam_events` table schema (`assessment_type`, `scoped_deck_ids`, `scoped_topics`).
  * **Loading & Error States:** Exam timetable shimmer list; confirmation modal on exam postponement.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Apply database schema migration and remove legacy fallback payload logic in `PlannerRepositoryImpl`.
* **P1 UX & Habit Loop:** Automated daily cram workload adjustment based on FSRS retention rates.
* **P2 Scale:** Calendar export (.ics format) integration for device native calendar apps.

---

### Feature 15: User Profile & Security Settings (`profile`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** Account security (MFA, password updates) protects student study records. Incomplete session revocation risks account compromise.
* **QA Operations:** `ActiveSessionsListWidget` renders current session but remote session termination API is not wired.
* **UI/UX Architect:** Avatar picker dialog lacks image crop handles before upload.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/profile/data/data_sources/profile_remote_data_source_impl.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/profile/data/data_sources/profile_remote_data_source_impl.dart)
  * **Current Mock Behavior:** Local state update for active sessions termination without calling backend session API.
  * **Required Backend Integration:** `DELETE /auth/v1/admin/users/{id}/factors/{factor_id}` and `POST /auth/v1/logout` (all devices).
  * **Loading & Error States:** Profile form save loader; toast notification on successful password update.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Wire TOTP 2FA setup to real Supabase MFA API (`enrollMfaFactor` and `verifyMfaFactor`).
* **P1 UX & Habit Loop:** Add study statistics summary card (total study hours, cards mastered) to Profile.
* **P2 Scale:** Support data export (GDPR compliant JSON bundle of all user study data).

---

### Feature 16: Past Questions & 1v1 Quiz Duel (`quiz`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** 1v1 Quiz Duels introduce social competition. Hardcoded duel questions degrade repeatability and engagement.
* **QA Operations:** `QuizDuelWebSocketClient.getDefaultDuelQuestions()` returns hardcoded Physics/Math questions when dynamic question fetch fails.
* **UI/UX Architect:** MCQ option cards lack distinct visual focus states for keyboard/gamepad navigation.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/quiz/data/client/quiz_duel_websocket_client.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/quiz/data/client/quiz_duel_websocket_client.dart#L38-L70)
  * **Current Mock Behavior:** Returns 2 hardcoded static questions (SI unit of electric potential & MATHEMATICS permutations) during duel initialization.
  * **Required Backend Integration:** `POST /rest/v1/rpc/generate_duel_questions` fetching dynamically from `past_questions` table.
  * **Loading & Error States:** Matchmaking radar scanning animation with animated match-found banner.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Replace hardcoded duel questions with dynamic backend RPC question loader; enforce server-side match result validation.
* **P1 UX & Habit Loop:** Implement Quiz Duel ELO ranking tiers (Bronze to Grandmaster) with seasonal rewards.
* **P2 Scale:** Add spectator mode for active high-tier quiz duels.

---

### Feature 17: Live Study Rooms & Audio RTC (`study_rooms`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** Virtual co-study creates accountability. Room connection failures drop co-working habit loops.
* **QA Operations:** Ephemeral room presence works via WebSocket broadcast, but room token generation uses local fallback logic when token service is unreachable.
* **UI/UX Architect:** Whiteboard canvas widget lacks multi-touch gesture lock during active drawing.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/study_rooms/data/services/livekit_audio_service_impl.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/study_rooms/data/services/livekit_audio_service_impl.dart#L67-L75)
  * **Current Mock Behavior:** Aborts connection silently with `LiveAudioConnectionState.failed` when LiveKit URL/token is empty without requesting fresh token from server.
  * **Required Backend Integration:** `POST /api/v1/livekit/token` endpoint returning signed JWTs for LiveKit Cloud.
  * **Loading & Error States:** Audio connection status banner (Connecting -> Connected / Reconnecting).

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Deploy LiveKit token generation microservice and connect `LiveKitAudioServiceImpl`.
* **P1 UX & Habit Loop:** Implement synchronized Pomodoro timer broadcast across all room participants.
* **P2 Scale:** Add cloud recording and automated AI transcript summary generation for study room sessions.

---

### Feature 18: Syllabot Socratic AI Assistant (`syllabot`)

#### A. Root-Cause Pain Point Matrix
* **PM (Habit & Retention):** Instant Socratic AI help solves learning roadblocks. Fake voice input stub creates broken user experience.
* **QA Operations:** `AudioInputWaveformButton` executes a `Future.delayed(2500ms)` timer and inputs a static hardcoded physics prompt string ("Derive the Euler-Lagrange equation...").
* **UI/UX Architect:** Streaming response text lacks smooth auto-scroll to bottom as new tokens arrive.

#### B. Mock & Dummy Data Purge Target List
* **Location:** [`lib/src/features/syllabot/presentation/widgets/audio_input_waveform_button.dart`](file:///Users/protector/Documents/projects/kortex/lib/src/features/syllabot/presentation/widgets/audio_input_waveform_button.dart#L52-L60)
  * **Current Mock Behavior:** `Future.delayed` stub producing static transcript string.
  * **Required Backend Integration:** Native Speech-To-Text STT engine integration (`speech_to_text` plugin / OpenAI Whisper REST API `/v1/audio/transcriptions`).
  * **Loading & Error States:** Real-time audio amplitude waveform indicator while recording; error toast on microphone permission refusal.

#### C. 3-Phase Execution Plan
* **P0 Stabilization & API Integration:** Wire `AudioInputWaveformButton` to production Whisper STT API; remove hardcoded prompt string.
* **P1 UX & Habit Loop:** Implement LaTeX scratchpad side-by-side with AI chat for math derivations.
* **P2 Scale:** Contextual RAG search across student's entire personal library of uploaded PDFs and decks.

---

## 3. Global Backend Integration Checklist

This consolidated checklist lists all API endpoints, RPC functions, and WebSocket channels required to purge **100%** of dummy data, fallbacks, and stubs across the entire Kortex EdTech platform.

### REST Endpoints & RPC Functions
* [ ] **Authentication & Profiles**
  * `POST /auth/v1/signup` — User registration with email/password.
  * `POST /auth/v1/token` — OAuth token exchange and login.
  * `POST /auth/v1/recover` — Send password reset recovery email.
  * `GET /rest/v1/user_profiles` — Fetch full user profile record.
  * `PATCH /rest/v1/user_profiles` — Update track, goals, and onboarding flag.
  * `POST /auth/v1/factors` — Enroll TOTP 2FA factor.

* [ ] **Curriculum & Onboarding**
  * `GET /rest/v1/curriculum_metadata` — Fetch official exam boards, tracks, and subjects.
  * `GET /rest/v1/course_tracks` — Fetch standard academic tracks catalog.

* [ ] **Dashboard & Analytics**
  * `GET /rest/v1/user_courses` — Fetch enrolled courses for active user.
  * `POST /rest/v1/rpc/get_dashboard_analytics_summary` — Aggregate retention rate, due cards, and study streak.

* [ ] **Decks & Flashcards**
  * `GET /rest/v1/decks` — Fetch user created and imported flashcard decks.
  * `POST /rest/v1/decks` — Create new deck record.
  * `POST /rest/v1/flashcards` — Bulk insert flashcards into deck.
  * `POST /rest/v1/rpc/sync_flashcard_reviews` — Sync FSRS review ratings batch.

* [ ] **Community & Marketplace**
  * `GET /rest/v1/forum_posts` — Fetch community discussions with filters.
  * `POST /rest/v1/rpc/fetch_forum_posts_keyset` — Keyset cursor pagination for forum feed.
  * `POST /rest/v1/rpc/fetch_forum_thread_tree` — Fetch nested reply trees.
  * `GET /rest/v1/shared_decks` — Query marketplace shared decks.
  * `POST /rest/v1/rpc/clone_shared_deck` — Clone shared deck into user's personal collection.

* [ ] **CBT Quiz & 1v1 Duels**
  * `GET /rest/v1/past_questions` — Query standardized past questions by subject/year.
  * `POST /rest/v1/rpc/generate_duel_questions` — Dynamic random question generator for 1v1 duels.
  * `POST /rest/v1/rpc/submit_quiz_results` — Persist CBT score and update user mastery.

* [ ] **Ingestion & LMS Proxy**
  * `POST /api/v1/lms/google/token` — OAuth2 proxy for Google Classroom integration.
  * `POST /api/v1/lms/canvas/token` — Canvas LMS API access token validator.
  * `POST /api/v1/audio/transcribe` — Speech-to-text transcript generation (Whisper API).

* [ ] **Live Study Rooms & WebRTC**
  * `POST /api/v1/livekit/token` — Generate signed JWT access token for LiveKit room.
  * `GET /rest/v1/study_rooms` — Fetch active public focus rooms.

* [ ] **Notifications & Monetization**
  * `POST /rest/v1/user_device_tokens` — Register FCM push notification token.
  * `POST /api/v1/webhooks/revenuecat` — RevenueCat subscription status webhook receiver.

---

### WebSocket Channels & Realtime Events
* [ ] **Supabase Realtime Broadcast / Postgres Changes**
  * `realtime:study_rooms` — Track active participant count, Pomodoro state, and ambient music track.
  * `realtime:forum_replies` — Instant notification of new replies on active forum threads.
  * `realtime:leaderboards` — Live score updates on weekly XP leaderboards.
  * `realtime:quiz_duel_matchmaking` — 1v1 Quiz Duel player matchmaking queue and presence.
  * `realtime:quiz_duel_{matchId}` — Realtime turn synchronized gameplay and emote broadcast.
