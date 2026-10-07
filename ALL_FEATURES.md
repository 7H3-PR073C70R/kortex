# Kortex — Comprehensive Feature Catalog & Sub-Feature Specification

> **Repository**: `kortex`  
> **Status**: Exhaustive Audit across Flutter Client (`lib/src`), Supabase Edge Functions (`supabase/functions`), Web Landing Suite (`web_landing`), Local Engines, and Developer Tooling.

---

## Executive Summary

**Kortex** is an enterprise-grade, neuro-adaptive AI learning and study ecosystem. It combines an offline-first Flutter application (Clean Architecture with BLoC/Cubit), a Supabase Cloud backend with serverless microservices, a Hybrid Retrieval-Augmented Generation (RAG) engine powered by Gemini/Local LLMs, real-time LiveKit audio rooms, an FSRS-v4 Spaced Repetition scheduler, real-time WebSockets quiz duels, and an interactive web landing & study tool suite.

Below is the complete, hierarchical catalog of **every feature and sub-feature** in the codebase.

---

## Table of Contents

1. [Authentication & Identity (`auth`)](#1-authentication--identity-auth)
2. [User Onboarding & Academic Calibration (`onboarding`, `onboarding_calibration`, `onboarding_utility`)](#2-user-onboarding--academic-calibration-onboarding-onboarding_calibration-onboarding_utility)
3. [AI Document Ingestion & Optical Character Recognition (`ingestion`)](#3-ai-document-ingestion--optical-character-recognition-ingestion)
4. [Decks & FSRS Spaced Repetition Engine (`decks`)](#4-decks--fsrs-spaced-repetition-engine-decks)
5. [Deck Marketplace & Community Sharing (`deck_marketplace`)](#5-deck-marketplace--community-sharing-deck_marketplace)
6. [Syllabot AI Tutor & RAG Engine (`syllabot`)](#6-syllabot-ai-tutor--rag-engine-syllabot)
7. [Interactive Quiz & Past Questions System (`quiz`)](#7-interactive-quiz--past-questions-system-quiz)
8. [Real-Time Live Study & Focus Rooms (`study_rooms`)](#8-real-time-live-study--focus-rooms-study_rooms)
9. [Community Hub & Peer Discussion Forums (`community`)](#9-community-hub--peer-discussion-forums-community)
10. [Dashboard & Cognitive Readiness Analytics (`dashboard`)](#10-dashboard--cognitive-readiness-analytics-dashboard)
11. [Exam Timetable & Cram Workload Planner (`planner`)](#11-exam-timetable--cram-workload-planner-planner)
12. [Gamification & Global Leaderboard (`leaderboard`)](#12-gamification--global-leaderboard-leaderboard)
13. [User Profile & Security Management (`profile`)](#13-user-profile--security-management-profile)
14. [Monetization & Subscriptions (`monetization`)](#14-monetization--subscriptions-monetization)
15. [Notifications & Alert Routing (`notifications`)](#15-notifications--alert-routing-notifications)
16. [Experimental On-Device Offline AI (`offline_ai`)](#16-experimental-on-device-offline-ai-offline_ai)
17. [App Version Control & Force Update (`force_update`)](#17-app-version-control--force-update-force_update)
18. [Core Architecture & Shared Platform Services (`core`, `shared`)](#18-core-architecture--shared-platform-services-core-shared)
19. [Supabase Backend Microservices (`supabase/functions`)](#19-supabase-backend-microservices-supabasefunctions)
20. [Web Landing Suite & Web Tools (`web_landing`)](#20-web-landing-suite--web-tools-web_landing)
21. [Developer Tooling, Automation & Scripts (`scripts/`, `tool/`)](#21-developer-tooling-automation--scripts-scripts-tool)

---

## 1. Authentication & Identity (`auth`)

Provides secure multi-modal authentication, social identity integration, biometric security, multi-factor authentication, session lifecycle control, and security route guards.

* **Primary Capabilities & Sub-Features**:
  * **1.1 Multi-Factor Authentication (MFA / 2FA)**
    * TOTP QR Code enrollment (`two_factor_setup_page.dart`)
    * Two-factor verification prompt on sensitive authentication flows
    * Backup recovery code generation and validation
  * **1.2 Social Authentication Engine (`SocialAuthService`)**
    * Google OAuth Single Sign-On (SSO)
    * Apple ID OAuth Sign-In integration
  * **1.3 Biometric Security & App Lock (`tailored_biometric_lock_view.dart`)**
    * Hardware capability detection (Face ID, Touch ID, Fingerprint)
    * Automatic background application blur and lock overlay on app switching
    * Secure PIN/Passcode fallback unlock mechanism
  * **1.4 Session & Token Management**
    * Automatic JWT token verification and background refresh via Dio interceptors
    * Security route guards (`AuthRouteGuard`) guarding restricted views
    * Multi-device active session tracking and remote session revocation
  * **1.5 User Registration & Account Recovery**
    * Multi-step email/password registration with real-time password strength meter
    * Password reset email dispatcher and password updating workflow

* **Key Files & Symbols**:
  * Pages: [login_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/auth/presentation/pages/login_page.dart), [register_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/auth/presentation/pages/register_page.dart), [forgot_password_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/auth/presentation/pages/forgot_password_page.dart)
  * State: [auth_bloc.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/auth/presentation/bloc/auth_bloc.dart), `auth_event.dart`, `auth_state.dart`
  * Domain: `login_use_case.dart`, `register_use_case.dart`, `social_login_use_case.dart`, `logout_use_case.dart`, `auth_route_guard.dart`

---

## 2. User Onboarding & Academic Calibration (`onboarding`, `onboarding_calibration`, `onboarding_utility`)

Controls initial app initialization, visual feature tours, academic profiling across high school and higher education tracks, OTP verification, and hardware permissions requests.

* **Primary Capabilities & Sub-Features**:
  * **2.1 Visual Onboarding & Initialization**
    * Multi-slide onboarding carousel (`onboarding_page.dart`) with vector animations
    * Dynamic splash screen (`splash_page.dart`) executing database migration checks and auth verification
  * **2.2 Academic Calibration Wizard**
    * **High School Tier**: Target exam profiling (WAEC, JAMB/UTME, NECO, IGCSE, SAT, AP), subject selection, and target exam timeline stepper
    * **Higher Education Tier**: Field of study selection, level selection (Undergraduate 100L–500L, Postgraduate), and academic goal setting
    * Academic curriculum resolver mapping subject metadata and localized icon assets
  * **2.3 Multi-Channel OTP Verification**
    * 6-digit SMS / Email OTP verification screen (`otp_verification_page.dart`)
    * Security resend countdown timer with anti-abuse throttling
  * **2.4 Hardware Permissions Wizard**
    * Interactive permissions request page (`permissions_page.dart`) for Camera (OCR), Microphone (Voice AI), and Notifications

* **Key Files & Symbols**:
  * Pages: [onboarding_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/onboarding/presentation/pages/onboarding_page.dart), [onboarding_calibration_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/onboarding_calibration/presentation/pages/onboarding_calibration_page.dart), [otp_verification_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/onboarding_utility/presentation/pages/otp_verification_page.dart), [permissions_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/onboarding_utility/presentation/pages/permissions_page.dart)
  * State: [calibration_cubit.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/onboarding_calibration/presentation/cubit/calibration_cubit.dart), `otp_cubit.dart`, `permissions_cubit.dart`
  * Widgets: `academic_focus_step.dart`, `high_school_exam_step.dart`, `high_school_subjects_step.dart`, `higher_ed_field_step.dart`, `higher_ed_level_step.dart`, `interactive_rocket_launch_overlay.dart`

---

## 3. AI Document Ingestion & Optical Character Recognition (`ingestion`)

Processes raw user learning materials (PDFs, PPTX files, camera scans, audio recordings, LMS imports) into structured flashcard decks and study units.

* **Primary Capabilities & Sub-Features**:
  * **3.1 Multi-Format File Ingestion**
    * Drag-and-drop file upload zone (`file_drop_zone_widget.dart`) supporting PDF, Microsoft PPTX, DOCX, and TXT files
    * Web article scraper extracting clean study text from URLs
  * **3.2 Camera Live OCR & STEM Math Engine**
    * On-device Google ML Kit text reader (`local_mlkit_ocr_client.dart`) for physical textbooks
    * Cloud fallback OCR service (`parse-stem-ocr`) for handwritten math and physics formulas
    * STEM equation reader with live interactive LaTeX preview and editor (`ocr_latex_live_editor.dart`)
  * **3.3 Document Pre-Processing & Deduplication**
    * SHA-256 document fingerprinting (`deep_document_dedup_service.dart`) preventing duplicate processing
    * Semantic recursive text splitter (`recursive_text_splitter.dart`) preserving formula context and headings
  * **3.4 Audio & LMS Import Connectors**
    * Voice lecture recorder and audio takeaway extractor (`audio_lecture_ingestion_sheet.dart`)
    * Canvas and Moodle LMS course importer (`lms_import_modal_sheet.dart`)
  * **3.5 Interactive AI Deck Synthesis Review**
    * Flashcard preview deck editor (`generated_cards_review_page.dart`) allowing card editing, deletion, or approval before deck generation

* **Key Files & Symbols**:
  * Pages: [document_ingestion_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/ingestion/presentation/pages/document_ingestion_page.dart), [generated_cards_review_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/ingestion/presentation/pages/generated_cards_review_page.dart), [ocr_preview_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/ingestion/presentation/pages/ocr_preview_page.dart)
  * Services: `document_parser_service.dart`, `local_pdf_parser_service.dart`, `local_pptx_parser_service.dart`, `deep_document_dedup_service.dart`, `local_image_ocr_service.dart`

---

## 4. Decks & FSRS Spaced Repetition Engine (`decks`)

The core flashcard engine powered by the **FSRS-v4 (Free Spaced Repetition Scheduler)** algorithm, multi-card format rendering, offline storage, and distraction-free study modes.

* **Primary Capabilities & Sub-Features**:
  * **4.1 FSRS-v4 Algorithm Engine (`fsrs_algorithm_engine.dart`)**
    * Computes Retrievability ($R$) and Stability ($S$) for optimal review intervals
    * Rating buttons: *Again*, *Hard*, *Good*, *Easy* updating card memory states
    * Custom weight parameter tuning ($w_0 \dots w_{18}$) per user
  * **4.2 Multi-Type Flashcard Support**
    * Standard Q&A text cards
    * Multiple Choice Question (MCQ) cards
    * Cloze deletion (fill-in-the-blank) cards
    * Image Occlusion canvas & viewer (`image_occlusion_canvas.dart`) for diagram masking
    * Formatted LaTeX math and syntax-highlighted code block cards
  * **4.3 Specialized Study Modes**
    * Standard Spaced Repetition review queue
    * Emergency Cram / Sprint Rush mode for immediate exam prep
    * Distraction-free Focus Workspace (`focus_workspace_page.dart`) with ambient noise generator and Pomodoro timer
    * Offline Flashcard Generator (`offline_flashcard_generation_page.dart`)
  * **4.4 Deck Management & Utilities**
    * Nested subdeck hierarchy tree (`subdeck_hierarchy_tree.dart`)
    * Conflict-Free Replicated Data Type (CRDT) deck merger (`crdt_deck_merger.dart`) for multi-device sync
    * Card similarity checker (`card_similarity_checker.dart`) preventing duplicates
    * Thought Parking Lot drawer (`thought_parking_lot_sheet.dart`) for taking side notes without interrupting study flow
    * Text-to-Speech (TTS) pronunciation reader (`audio_pronounce_button.dart`)

* **Key Files & Symbols**:
  * Pages: [decks_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/decks/presentation/pages/decks_page.dart), [create_deck_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/decks/presentation/pages/create_deck_page.dart), [study_session_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/decks/presentation/pages/study_session_page.dart), [focus_workspace_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/decks/presentation/pages/focus_workspace_page.dart), [session_summary_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/decks/presentation/pages/session_summary_page.dart)
  * Engine: [fsrs_algorithm_engine.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/decks/domain/services/fsrs_algorithm_engine.dart), `crdt_deck_merger.dart`, `card_similarity_checker.dart`

---

## 5. Deck Marketplace & Community Sharing (`deck_marketplace`)

Enables users to discover, publish, preview, and clone community-curated study decks.

* **Primary Capabilities & Sub-Features**:
  * **5.1 Deck Discovery & Search**
    * Browse public deck repository by subject, target exam, academic tier, and popularity rating
    * Detailed preview page (`deck_marketplace_detail_page.dart`) displaying deck stats, creator profile, and sample cards
  * **5.2 1-Tap Deck Cloning**
    * Clones shared public decks (`clone_shared_deck_use_case.dart`) into user's personal database with fresh FSRS metrics
  * **5.3 Deck Publishing Studio**
    * Deck publisher sheet (`publish_deck_modal_sheet.dart`) with licensing, tagging, and preview setup

* **Key Files & Symbols**:
  * Pages: [deck_marketplace_detail_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/deck_marketplace/presentation/pages/deck_marketplace_detail_page.dart)
  * Widgets: `marketplace_deck_card.dart`, `publish_deck_modal_sheet.dart`
  * Use Cases: `clone_shared_deck_use_case.dart`

---

## 6. Syllabot AI Tutor & RAG Engine (`syllabot`)

A context-aware AI academic assistant supporting local/cloud hybrid inference, Socratic tutoring, document vector RAG, voice dialogue, and instant chat-to-flashcard deck generation.

* **Primary Capabilities & Sub-Features**:
  * **6.1 Hybrid Cloud/Local Execution Engine**
    * Execution router (`execution_engine_router.dart`) dynamically switching between Cloud Gemini API and On-Device local LLM based on user preference and network status
  * **6.2 Socratic Guidance Mode**
    * Mode selector (`socratic_mode_selector.dart`) guiding students with hints and prompts rather than providing direct solutions
  * **6.3 Document Vector RAG Engine**
    * Vector database search (`vector_search_client.dart`) querying uploaded course materials
    * Interactive RAG reference badges (`rag_reference_badge.dart`) linking directly to source document chunks and page numbers
  * **6.4 Interactive Chat Tools**
    * Chat LaTeX Scratchpad (`chat_latex_scratchpad_widget.dart`) for viewing and editing step-by-step math solutions
    * Voice Dialogue Modal (`voice_dialogue_modal.dart`) providing hands-free conversational tutoring with animated audio spectrum
    * Chat-to-Deck Generator (`generate_deck_from_chat_use_case.dart`): converts chat explanations into saved flashcard decks in 1 tap

* **Key Files & Symbols**:
  * Pages: [syllabot_chat_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/syllabot/presentation/pages/syllabot_chat_page.dart)
  * State: `syllabot_chat_bloc.dart`, `syllabot_chat_event.dart`, `syllabot_chat_state.dart`
  * Clients: `syllabot_api_client.dart`, `vector_search_client.dart`, `local_llm_engine_client.dart`, `execution_engine_router.dart`

---

## 7. Interactive Quiz & Past Questions System (`quiz`)

A comprehensive examination preparation environment featuring real national past questions, Computer-Based Test (CBT) simulations, multiplayer 1v1 Quiz Duels, and a gamified arcade mode.

* **Primary Capabilities & Sub-Features**:
  * **7.1 Computer-Based Test (CBT) Examination Simulator**
    * Timed examination environment (`quiz_workspace_page.dart`) mirroring JAMB/WAEC exam software
    * Question flagger, formula reference sheet, answer selection grid, and built-in calculator
  * **7.2 Official Past Questions Archive**
    * Archive browser (`past_questions_board_page.dart`) filtering WAEC, JAMB/UTME, NECO, POST-UTME, and SAT questions by year, subject, and topic
    * AI-synthesized answer explanations and difficulty classification
  * **7.3 1v1 Real-Time Quiz Duel Arena**
    * Multiplayer quiz battle ground (`quiz_duel_arena_page.dart`) synchronized via WebSockets (`quiz_duel_websocket_client.dart`)
    * Competitive ELO ranking tiers (`quiz_duel_elo_tier.dart`) and match leaderboards
  * **7.4 Academic "Who Wants to Be a Millionaire" Arcade**
    * Trivia arcade game mode with progressive prize scaling (`millionaire_tiering_engine.dart`)
    * Interactive Lifelines: Audience Poll (`millionaire_audience_poll_dialog.dart`), 50:50 elimination, and Phone-an-AI-Friend
  * **7.5 Remedial Deck Generation**
    * Failed Quiz Converter (`convert_failed_quiz_to_deck_use_case.dart`): turns missed quiz questions into a targeted FSRS flashcard deck

* **Key Files & Symbols**:
  * Pages: [quiz_workspace_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/quiz/presentation/pages/quiz_workspace_page.dart), [past_questions_board_page.dart](file:///Users/protector/Documents/projects/quiz/presentation/pages/past_questions_board_page.dart), [quiz_duel_arena_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/quiz/presentation/pages/quiz_duel_arena_page.dart), [quiz_results_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/quiz/presentation/pages/quiz_results_page.dart)
  * State: `quiz_session_cubit.dart`, `quiz_duel_cubit.dart`, `past_questions_bloc.dart`

---

## 8. Real-Time Live Study & Focus Rooms (`study_rooms`)

Collaborative virtual study rooms featuring low-latency LiveKit voice channels, real-time shared whiteboard canvas, ephemeral member presence, and live reactions.

* **Primary Capabilities & Sub-Features**:
  * **8.1 LiveKit Voice Audio Channels**
    * WebRTC real-time voice streaming (`livekit_audio_service_impl.dart`) with mute and audio device management
  * **8.2 Multi-User Ephemeral Presence**
    * Participant list showing live avatars, current study status, focus timers, and speaking indicators (`ephemeral_presence_client.dart`)
  * **8.3 Collaborative Whiteboard Canvas**
    * Real-time vector drawing canvas (`whiteboard_canvas_widget.dart`) with binary stroke compression (`whiteboard_compression.dart`)
  * **8.4 Room Study Tools & Interactions**
    * Shared flashcard study workspace (`in_room_deck_study_workspace.dart`) for group card review
    * Floating animated reaction bursts (`floating_reaction_overlay.dart`)
    * In-room text chat drawer and voice message recorder

* **Key Files & Symbols**:
  * Pages: [study_hub_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/study_rooms/presentation/pages/study_hub_page.dart), [live_study_room_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/study_rooms/presentation/pages/live_study_room_page.dart)
  * Cubit: [live_room_cubit.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/study_rooms/presentation/cubit/live_room_cubit.dart)
  * Services: `livekit_audio_service.dart`, `whiteboard_compression.dart`, `ephemeral_presence_client.dart`

---

## 9. Community Hub & Peer Discussion Forums (`community`)

Automated course community channels, peer discussion threads, AI Socratic homework helpers, content moderation, and audio spoken math accessibility.

* **Primary Capabilities & Sub-Features**:
  * **9.1 Course Community Auto-Provisioning**
    * Dynamic course and exam forum provisioner (`auto_provision_community_use_case.dart`) linking users taking identical subjects
  * **9.2 Rich Thread Discussion Feed**
    * Authoring screen (`create_forum_discussion_page.dart`) supporting rich text, images, code snippets, LaTeX formulas, and voice notes
  * **9.3 AI Socratic Peer Assistant**
    * Socratic hint service (`forum_socratic_hint_service.dart`) analyzing posted homework questions and attaching expandable hint guidance
  * **9.4 Content Moderation & Spoken Math Accessibility**
    * Automated moderation scanner (`content_moderation_service.dart`) and user flagging modal
    * Spoken Math Converter (`spoken_math_converter.dart`) reading LaTeX expressions in natural spoken language for vision-impaired users

* **Key Files & Symbols**:
  * Pages: [community_hub_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/community/presentation/pages/community_hub_page.dart), [create_forum_discussion_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/community/presentation/pages/create_forum_discussion_page.dart), [forum_thread_detail_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/community/presentation/pages/forum_thread_detail_page.dart)
  * State: `community_hub_bloc.dart`, `auto_community_cubit.dart`

---

## 10. Dashboard & Cognitive Readiness Analytics (`dashboard`)

Central user analytics hub featuring algorithmic exam readiness gauges, Ebbinghaus memory decay charts, GitHub-style activity heatmaps, and curated course modules.

* **Primary Capabilities & Sub-Features**:
  * **10.1 Algorithmic CBT Exam Readiness Gauge**
    * Exam score predictor (`cbt_readiness_calculator.dart`) calculating readiness percentages based on recall speed, question difficulty, and FSRS retrievability
  * **10.2 Ebbinghaus Memory Decay Visualizer**
    * Retention chart (`adaptive_retention_chart.dart`) projecting knowledge retention curves over 30 days
  * **10.3 Activity Intensity & Streak Shield**
    * GitHub-style daily study activity heatmap (`study_activity_heatmap.dart`)
    * Streak shield protection indicator (`streak_shield_indicator.dart`) tracking active streaks and shield inventory
  * **10.4 Auto-Curated Course Modules**
    * Curriculum planner (`auto_curate_exam_courses_use_case.dart`) organizing study modules according to target exam dates

* **Key Files & Symbols**:
  * Pages: [dashboard_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/dashboard/presentation/pages/dashboard_page.dart), [analytics_detail_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/dashboard/presentation/pages/analytics_detail_page.dart), [course_module_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/dashboard/presentation/pages/course_module_page.dart)
  * Calculators: `cbt_readiness_calculator.dart`, `ebbinghaus_decay_calculator.dart`

---

## 11. Exam Timetable & Cram Workload Planner (`planner`)

Smart examination countdown timer and study workload optimizer designed to ensure complete syllabus coverage before exam dates.

* **Primary Capabilities & Sub-Features**:
  * **11.1 Cram Workload Calculator**
    * Workload optimizer (`cram_workload_calculator.dart`) calculating exact daily card review quotas and practice question targets needed prior to exam day
  * **11.2 Exam Countdown & Syllabus Checklist**
    * Live countdown ticker banners (`exam_countdown_banner.dart`) for upcoming exams
    * Interactive syllabus checklist (`syllabus_checklist_widget.dart`) for tracking topic completion

* **Key Files & Symbols**:
  * Pages: [exam_timetable_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/planner/presentation/pages/exam_timetable_page.dart)
  * Cubit: [cram_planner_cubit.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/planner/presentation/cubit/cram_planner_cubit.dart)
  * Widgets: `exam_countdown_banner.dart`, `syllabus_checklist_widget.dart`, `add_exam_modal_sheet.dart`

---

## 12. Gamification & Global Leaderboard (`leaderboard`)

Competitive student ranking system with XP leagues, podium displays, promotion celebrations, and streak preservation shields.

* **Primary Capabilities & Sub-Features**:
  * **12.1 Real-Time League Rankings**
    * Streamed global and course-level XP rankings (`stream_leaderboard_rankings_use_case.dart`)
  * **12.2 Top Scholar Podium & Promotion Modals**
    * Top 3 podium display (`leaderboard_podium_widget.dart`)
    * Tier promotion celebration modal (`tier_promotion_celebration_modal.dart`) with animation effects
  * **12.3 Streak Shield Protection**
    * Streak freeze modal (`streak_freeze_shield_sheet.dart`) allowing students to protect study streaks during rest days

* **Key Files & Symbols**:
  * Pages: [leaderboard_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/leaderboard/presentation/pages/leaderboard_page.dart)
  * Widgets: `leaderboard_podium_widget.dart`, `leaderboard_rank_card.dart`, `tier_promotion_celebration_modal.dart`, `streak_freeze_shield_sheet.dart`

---

## 13. User Profile & Security Management (`profile`)

User account management, notification controls, 2FA setup, active session security, and AI behavior preferences.

* **Primary Capabilities & Sub-Features**:
  * **13.1 Account & Academic Settings**
    * Profile avatar uploader, display name editor, bio editor, and academic track switcher
  * **13.2 Security & 2FA Configuration**
    * TOTP Two-Factor Authentication setup screen (`two_factor_setup_page.dart`) with QR code scanner and manual key entry
    * Active login session list (`active_sessions_list_widget.dart`) allowing 1-tap remote device sign-out
  * **13.3 Syllabot AI Preference Controls**
    * AI settings screen (`syllabot_ai_settings_page.dart`) for adjusting AI verbosity, Socratic strictness, and Cloud/Local model selection

* **Key Files & Symbols**:
  * Pages: [profile_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/profile/presentation/pages/profile_page.dart), [security_settings_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/profile/presentation/pages/security_settings_page.dart), [two_factor_setup_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/profile/presentation/pages/two_factor_setup_page.dart), [syllabot_ai_settings_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/profile/presentation/pages/syllabot_ai_settings_page.dart)

---

## 14. Monetization & Subscriptions (`monetization`)

In-app subscription billing and entitlement enforcement powered by RevenueCat SDK and promo code redemption.

* **Primary Capabilities & Sub-Features**:
  * **14.1 RevenueCat Subscription Engine**
    * Billing integration (`revenuecat_service.dart`) managing Free vs. Pro entitlement state
  * **14.2 Domain Entitlement Guards**
    * Feature gate service (`subscription_guard.dart`) restricting premium capabilities (e.g. unlimited local AI, premium decks)
  * **14.3 Promo Code Redemption**
    * Custom promo code redemption modal (`promo_code_modal_sheet.dart`) for unlocking trial access

* **Key Files & Symbols**:
  * Pages: [paywall_screen.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/monetization/presentation/pages/paywall_screen.dart)
  * Services: `subscription_guard.dart`, `revenuecat_service.dart`
  * Widgets: `promo_code_modal_sheet.dart`

---

## 15. Notifications & Alert Routing (`notifications`)

In-app notification inbox and push notification routing for study reminders, streak warnings, duel invites, and forum replies.

* **Primary Capabilities & Sub-Features**:
  * **15.1 In-App Notification Inbox**
    * Filterable notification feed (`notifications_page.dart`) supporting read/unread toggles and deep-link routing
  * **15.2 Push Notification Microservice**
    * Supabase push notification dispatcher (`trigger-notifications`, `send-push-notification`) delivering Firebase Cloud Messaging (FCM) alerts

* **Key Files & Symbols**:
  * Pages: [notifications_page.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/notifications/presentation/pages/notifications_page.dart)
  * Cubit: `notifications_cubit.dart`

---

## 16. Experimental On-Device Offline AI (`offline_ai`)

Local LLM isolate manager enabling full AI flashcard synthesis and tutoring without active internet connection.

* **Primary Capabilities & Sub-Features**:
  * **16.1 Dedicated Isolate Execution**
    * Background Isolate Manager (`local_inference_isolate_manager.dart`) executing GGML/GGUF quantized AI models without UI jank
  * **16.2 Hardware Compatibility Guard**
    * Device capability benchmark (`experimental_offline_guard.dart`) checking RAM and CPU specs before allocating local models

* **Key Files & Symbols**:
  * Services: `local_inference_isolate_manager.dart`, `experimental_offline_guard.dart`

---

## 17. App Version Control & Force Update (`force_update`)

App version control feature that checks remote minimum version requirements, displays release notes, and provides direct app store update redirects.

* **Primary Capabilities & Sub-Features**:
  * **17.1 Mandatory Version Enforcer**
    * Version checker evaluating client version against remote minimum required version
    * Non-dismissible update screen (`force_update_screen.dart`) for obsolete app builds
  * **17.2 Release Notes & Store Redirects**
    * Version changelog viewer and direct buttons to Apple App Store, Google Play Store, and direct download links

* **Key Files & Symbols**:
  * Pages: [force_update_screen.dart](file:///Users/protector/Documents/projects/kortex/lib/src/features/force_update/presentation/pages/force_update_screen.dart)

---

## 18. Core Architecture & Shared Platform Services (`core`, `shared`)

Foundational platform infrastructure powering offline storage, cloud sync, design tokens, multi-format study exporting, and global UI overlays.

* **Primary Capabilities & Sub-Features**:
  * **18.1 Local SQLite Database (Drift)**
    * Persistent SQLite database (`app_database.dart`, `tables.dart`) managing offline decks, flashcards, session history, and cached vector chunks
  * **18.2 Bi-Directional Cloud Sync Engine**
    * Background synchronization engine (`app_sync_engine.dart`) resolving local SQLite changes with Supabase Cloud DB
  * **18.3 Modern Design System & Themes**
    * Neural palette styling system (`neural_palette.dart`, `app_theme.dart`) with custom glassmorphism components (`app_liquid_card.dart`, `app_liquid_tab_bar.dart`)
  * **18.4 Multi-Format Study Export Suite**
    * Native Anki deck exporter (`anki_export_service.dart`) compiling `.apkg` packages
    * Notion CSV study guide generator (`notion_csv_formatter.dart`)
    * Print-ready PDF study worksheet generator (`pdf_printable_generator.dart`)
  * **18.5 Global UI Overlays & Hardware Benchmarking**
    * Global floating Syllabot AI overlay button (`floating_syllabot_overlay.dart`)
    * Hardware benchmark utility (`device_performance_benchmark.dart`) adjusting graphics and local AI parameters based on device specs
    * Milestone celebration overlay (`gratification_celebration_overlay.dart`) with animated confetti

* **Key Files & Symbols**:
  * DB: [app_database.dart](file:///Users/protector/Documents/projects/kortex/lib/src/core/database/app_database.dart), `tables.dart`
  * Sync: `app_sync_engine.dart`
  * Export: `anki_export_service.dart`, `notion_csv_formatter.dart`, `pdf_printable_generator.dart`

---

## 19. Supabase Backend Microservices (`supabase/functions`)

TypeScript serverless functions running on Deno powering cloud AI streaming, document parsing, real-time audio tokens, cron jobs, and webhooks.

| Microservice Function | Description & Key Sub-Features |
| :--- | :--- |
| `syllabot-stream/` | Streams AI responses via Server-Sent Events (SSE) with semantic caching (`semantic_cache_provider.ts`). |
| `process-document-ingestion/` | Async cloud document parser splitting uploaded PDFs/PPTX files into semantic markdown chunks (`markdown_chunker.ts`). |
| `generate-flashcards-stream/` | Real-time streaming AI flashcard synthesis engine. |
| `parse-stem-ocr/` | Cloud LaTeX OCR parser resolving complex math and physics formulas from image inputs. |
| `generate-quiz-questions/` | AI question generator synthesizing CBT exam items based on syllabus topics. |
| `calculate-leaderboard/` | Cron-triggered microservice computing weekly global XP rankings and league promotions. |
| `revenuecat-webhook/` | Listens to RevenueCat webhooks to update user subscription entitlements in Supabase. |
| `generate-livekit-token/` | Issues secure access tokens for LiveKit WebRTC study room connections. |
| `presence-heartbeat/` | Manages active room participant heartbeats and clears inactive connections. |
| `provision-course-community/` | Automatically provisions discussion channels for newly registered courses. |
| `upload-forum-media/` | Media upload endpoint performing file security and virus checks. |
| `trigger-notifications` & `send-push-notification` | FCM push notification dispatchers. |
| `generate-embeddings/` | Generates vector embeddings for study document chunks. |
| `get-admin-leads` & `verify-admin-token` | Administrative endpoints for telemetry and user lead tracking. |
| `cleanup-ai-sessions/` | Maintenance job clearing expired AI response caches and temporary upload buffers. |

---

## 20. Web Landing Suite & Web Tools (`web_landing`)

A modern marketing hub and standalone interactive web study tools suite built for high conversion, user onboarding, and web-based study.

* **Primary Capabilities & Sub-Features**:
  * **20.1 Web Marketing Hub (`index.html`)**
    * Interactive AI demo widget, feature highlights, live testimonials, and dynamic pricing tier calculator
  * **20.2 Standalone Web Study Tools**
    * **AI Question & CBT Generator** ([questions.html](file:///Users/protector/Documents/projects/kortex/web_landing/features/questions.html)): Generate custom CBT practice questions directly in the browser
    * **AI Flashcard Creator** ([flashcards.html](file:///Users/protector/Documents/projects/kortex/web_landing/features/flashcards.html)): Create flashcard sets from plain text inputs
    * **AI Step-by-Step Problem Solver** ([solver.html](file:///Users/protector/Documents/projects/kortex/web_landing/features/solver.html)): Solve STEM problem statements with detailed step-by-step guidance
    * **Interactive Study Summary Generator** ([summary.html](file:///Users/protector/Documents/projects/kortex/web_landing/features/summary.html)): Summarize long study notes into concise executive bullet points
    * **AI Academic Glossary Generator** ([glossary.html](file:///Users/protector/Documents/projects/kortex/web_landing/features/glossary.html)): Auto-generate key term definitions and glossaries
  * **20.3 Multi-Platform Distribution Hub (`downloads.html`)**
    * Direct downloads for iOS, Android, macOS, Windows, Linux, and Web app links
  * **20.4 Admin Lead Telemetry Dashboard (`internal_leads.html`)**
    * Internal analytics and lead management portal protected by admin token authentication (`verify-admin-token`)
  * **20.5 Public & Legal Pages**
    * Pricing page (`pricing.html`), Privacy Policy (`privacy.html`), Terms of Service (`terms.html`), Contact Form (`contact.html`)

---

## 21. Developer Tooling, Automation & Scripts (`scripts/`, `tool/`)

Scripts and CLI tools used for dataset preparation, scraping academic syllabi, local testing, and production deployment.

* **Primary Capabilities & Sub-Features**:
  * **Local Ollama Fallback Engine** (`ollama_fallback_generator.py`): CLI utility for testing offline AI card synthesis against local Ollama models
  * **Academic Web Crawlers** (`scripts/crawler/`): BeautifulSoup4 Python scrapers for fetching national exam syllabi and question banks
  * **Database Seeders** (`scripts/seed_forum_discussions.py`, `scripts/sync_myschool_subjects.py`): Automated scripts populating test discussion threads and subject metadata
  * **Analytics Exporter** (`scripts/export_leads.py`): Telemetry data export tool
  * **Production Build & Deployment Pipeline** (`scripts/deploy_production.sh`): Script for building Flutter release binaries and deploying Supabase Edge Functions

---

## Summary Matrix of Feature Modules

| Feature Module | Primary Location | Key Technical Architecture |
| :--- | :--- | :--- |
| **Authentication & Identity** | `lib/src/features/auth` | Supabase Auth, Biometrics, OAuth SSO, Route Guards |
| **Academic Calibration** | `lib/src/features/onboarding_calibration` | BLoC, Custom Curriculum Resolver, Stepper UI |
| **Document Ingestion & OCR** | `lib/src/features/ingestion` | ML Kit OCR, Cloud LaTeX OCR, Deep Dedup |
| **Decks & FSRS Spaced Repetition** | `lib/src/features/decks` | FSRS-v4 Algorithm, Drift SQLite, Image Occlusion |
| **Deck Marketplace** | `lib/src/features/deck_marketplace` | Public Repositories, 1-Tap Deck Cloning |
| **Syllabot AI Tutor & RAG** | `lib/src/features/syllabot` | Hybrid Cloud/Local LLM Router, Vector RAG |
| **Quiz & Past Questions** | `lib/src/features/quiz` | CBT Simulator, Millionaire Arcade, WebSocket Duels |
| **Live Focus Study Rooms** | `lib/src/features/study_rooms` | LiveKit WebRTC Audio, Shared Vector Whiteboard |
| **Community Forums** | `lib/src/features/community` | Auto-Provisioned Channels, AI Socratic Assistant |
| **Dashboard & Readiness Analytics** | `lib/src/features/dashboard` | Ebbinghaus Decay Calculator, Readiness Gauge |
| **Exam Timetable & Planner** | `lib/src/features/planner` | Cram Workload Calculator, Countdown Banners |
| **Gamification & Leaderboard** | `lib/src/features/leaderboard` | Real-time Rankings, Tier Promotions, Streak Freeze |
| **User Profile & Security** | `lib/src/features/profile` | 2FA TOTP Setup, Remote Session Revocation |
| **Monetization Engine** | `lib/src/features/monetization` | RevenueCat SDK, Subscription Feature Guards |
| **Notifications** | `lib/src/features/notifications` | In-App Inbox, Firebase Push Notifications |
| **Experimental Offline AI** | `lib/src/features/offline_ai` | Dedicated Dart Isolate, GGUF/GGML Local Models |
| **App Version Control** | `lib/src/features/force_update` | Version Check Enforcer, Release Notes |
| **Core Infrastructure** | `lib/src/core`, `lib/src/shared` | Drift DB, App Sync Engine, Anki/Notion/PDF Exporters |
| **Supabase Edge Microservices** | `supabase/functions/` | TypeScript, Deno, SSE Streams, Vector Embeddings |
| **Web Landing & Tools** | `web_landing/` | Interactive HTML/JS Web Tools, Lead Telemetry |
| **Developer Tools & Scripts** | `scripts/`, `tool/` | Python Ollama Engine, Syllabi Crawlers |
