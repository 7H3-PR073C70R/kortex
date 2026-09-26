# Kortex — System Architecture & Exhaustive Feature Catalog

> **Generated**: September 26, 2026  
> **Repository**: `kortex`  
> **Scope**: Complete, deep-file code audit across Flutter client (`lib/src`), Supabase Edge Functions (`supabase/functions`), local databases, domain engines, and backend automation tooling.

---

## 1. Executive Architecture Overview

Kortex is an AI-powered, neuro-adaptive learning and study ecosystem built on Flutter (Clean Architecture with BLoC/Cubit), powered by a Supabase cloud backend, an on-device/cloud Hybrid RAG (Retrieval-Augmented Generation) pipeline, real-time LiveKit audio rooms, and an enterprise-grade FSRS-v4 (Free Spaced Repetition Scheduler) engine.

```
                           +----------------------------------+
                           |     Kortex Flutter App (v1.0)    |
                           +----------------------------------+
                                           |
      +--------------------+---------------+-------------------+--------------------+
      |                    |               |                   |                    |
+-------------+    +---------------+  +----------+   +-------------------+   +---------------+
| Auth & User |    | Study & Quiz  |  | Decks &  |   | Syllabot AI RAG   |   | Live Focus &  |
| Calibration |    | CBT Engine    |  | FSRS v4  |   | (Cloud/Local LLM) |   | Audio Rooms   |
+-------------+    +---------------+  +----------+   +-------------------+   +---------------+
      |                    |               |                   |                    |
+-------------------------------------------------------------------------------------------+
|                                  Core Layer & Shared Infra                                |
|  Drift SQLite DB | App Sync Engine | Liquid Glass Design | Anki/PDF Exporter | Hardware Guard|
+-------------------------------------------------------------------------------------------+
                                           |
+-------------------------------------------------------------------------------------------+
|                              Supabase Cloud & Edge Services                               |
|  Edge Functions | Vector Embeddings | LiveKit RTC | RevenueCat Billing | Realtime Sockets |
+-------------------------------------------------------------------------------------------+
```

---

## 2. Comprehensive Feature Modules Catalog

---

### 2.1. Authentication & Identity (`auth`)

Provides multi-modal user authentication, social identity integration, biometric security, session persistence, and academic track onboarding.

* **Primary Capabilities**:
  * Email & Password sign-up / sign-in with multi-factor authentication (MFA).
  * OAuth Social Sign-In (Google, Apple) integrated via `SocialAuthService`.
  * Biometric Authentication (Face ID, Touch ID, Fingerprint) with fallback passcodes.
  * Auto-routing based on authentication state and academic onboarding completion.
  * Session token auto-refresh, token verification, and security route guards (`AuthRouteGuard`).

* **Detailed File & Symbol Structure**:
  * **Presentation Pages**:
    * `login_page.dart`: Interactive login interface with social login & biometric unlock options.
    * `register_page.dart`: Multi-step registration with password strength meter and terms acceptance.
    * `forgot_password_page.dart`: Password recovery flow.
  * **State Management**:
    * `auth_bloc.dart`, `auth_event.dart`, `auth_state.dart`: Manages global auth lifecycle (`Unauthenticated`, `Authenticating`, `Authenticated`, `AuthError`).
  * **Domain Layer**:
    * **Use Cases**: `login_use_case.dart`, `register_use_case.dart`, `social_login_use_case.dart`, `logout_use_case.dart`, `get_current_user_use_case.dart`, `check_auth_status_use_case.dart`.
    * **Entities**: `user_entity.dart`, `user_profile_entity.dart`, `course_track_entity.dart`, `auth_status.dart`.
    * **Services**: `auth_route_guard.dart`.
  * **Data Layer**:
    * `auth_repository_impl.dart`, `auth_remote_data_source_impl.dart`, `auth_api_client.dart`.
    * **Models**: `user_model.dart`, `user_profile_model.dart`, `auth_request_model.dart`, `course_track_model.dart`.

---

### 2.2. User Onboarding & Academic Calibration (`onboarding`, `onboarding_calibration`, `onboarding_utility`)

Initial user setup experience, interactive feature tour, academic level profiling, high school/higher education exam tracking, and OTP verification.

* **Primary Capabilities**:
  * Multi-step visual onboarding carousel with interactive launch graphics.
  * Academic track calibration: High School (WAEC, JAMB/UTME, NECO, IGCSE, SAT) vs. Higher Education (Undergraduate/Postgraduate field of study & level).
  * Curriculum icon resolution and dynamic subject metadata generation.
  * Phone/Email OTP verification with resend throttling and security check.
  * Device permissions wizard (Camera, Notifications, Microphone).

* **Detailed File & Symbol Structure**:
  * **Presentation Pages**:
    * `onboarding_page.dart`: Welcome onboarding slider.
    * `splash_page.dart`: Dynamic splash view verifying session state and database migrations.
    * `onboarding_calibration_page.dart`: High-level stepper screen for academic profiling.
    * `otp_verification_page.dart`: 6-digit OTP verification interface.
    * `permissions_page.dart`: Hardware permissions request flow.
  * **State Management**:
    * `calibration_cubit.dart`, `calibration_state.dart`: Tracks user choices across academic tiers.
    * `otp_cubit.dart`: Handles OTP resend timers and submission.
    * `permissions_cubit.dart`: Manages system permission state.
  * **Domain & Data Layer**:
    * **Use Cases**: `save_calibration_profile_use_case.dart`, `get_calibration_profile_use_case.dart`, `verify_otp_use_case.dart`, `resend_otp_use_case.dart`.
    * **Widgets**: `academic_focus_step.dart`, `high_school_exam_step.dart`, `high_school_subjects_step.dart`, `high_school_timeline_step.dart`, `higher_ed_field_step.dart`, `higher_ed_goals_step.dart`, `higher_ed_level_step.dart`, `calibration_step_tracker.dart`, `interactive_rocket_launch_overlay.dart`.
    * **Repositories & Sources**: `calibration_repository_impl.dart`, `curriculum_repository_impl.dart`, `onboarding_local_data_source.dart`.

---

### 2.3. AI Document Ingestion & Optical Character Recognition (`ingestion`)

Transforms raw user inputs (PDFs, PPTX files, camera scans, audio lectures, LMS imports) into structured flashcards and study modules using local and cloud OCR/parsing engines.

* **Primary Capabilities**:
  * Multi-format Document Processing: PDF, Microsoft PPTX, plain text, and web files.
  * Camera Live OCR & STEM LaTeX Equation Reader: Captures handwritten math/physics equations via Google ML Kit (`local_mlkit_ocr_client.dart`) and cloud fallback (`parse-stem-ocr`).
  * Deep Document Deduplication (`deep_document_dedup_service.dart`): Prevents redundant processing of identical study materials.
  * Recursive Text Chunking (`recursive_text_splitter.dart`): Smart semantic chunking preserving heading context and formulas.
  * Audio Lecture Ingestion (`audio_lecture_ingestion_sheet.dart`): Extracts key study points from recorded voice lectures.
  * LMS Import Integration (`lms_import_modal_sheet.dart`): Direct import of Canvas/Moodle course materials.
  * Interactive Flashcard Synthesis Review (`generated_cards_review_page.dart`): Allows users to accept, modify, or reject AI-generated cards before saving.

* **Detailed File & Symbol Structure**:
  * **Presentation Pages**:
    * `document_ingestion_page.dart`: File drop zone & multi-file upload hub.
    * `generated_cards_review_page.dart`: Swipeable preview deck editor for synthetic cards.
    * `ocr_preview_page.dart`: Interactive crop, LaTeX extraction, and live LaTeX editor preview.
  * **State Management**:
    * `ingestion_bloc.dart`, `ingestion_event.dart`, `ingestion_state.dart`.
  * **Domain Services & Logic**:
    * `document_parser_service.dart`: Coordinates local and remote parsing.
    * `local_pdf_parser_service.dart` & `local_pptx_parser_service.dart`: Native document extractors.
    * `local_image_ocr_service.dart`: Local ML Kit OCR scanner.
    * `deep_document_dedup_service.dart`: SHA-256 fingerprint matching for files.
    * `onboarding_stream_controller.dart`: Real-time ingestion progress updates.
  * **Use Cases**:
    * `upload_study_document_use_case.dart`, `generate_flashcards_from_doc_use_case.dart`, `process_stem_ocr_use_case.dart`, `process_local_camera_ocr_use_case.dart`, `fetch_user_documents_use_case.dart`, `import_lms_course_use_case.dart`, `fetch_lms_courses_use_case.dart`.
  * **UI Widgets**:
    * `file_drop_zone_widget.dart`, `camera_scanner_overlay.dart`, `camera_live_ocr_overlay.dart`, `ocr_latex_live_editor.dart`, `synthesis_mode_toggle.dart`, `upload_progress_card.dart`, `background_ingestion_indicator.dart`.

---

### 2.4. Decks & Spaced Repetition Study Engine (`decks`)

Core flashcard management system powered by the **FSRS-v4 (Free Spaced Repetition Scheduler)** algorithm. Supports multi-type cards, offline sync, CRDT collaborative editing, and study session analytics.

* **Primary Capabilities**:
  * **FSRS-v4 Algorithm**: Scientifically proven spaced repetition algorithm (`fsrs_algorithm_engine.dart`) computing Retrievability ($R$) and Stability ($S$). Supports user tuning of weights ($w_0 \dots w_{18}$).
  * **Card Types**: Standard Q&A, Multiple Choice (MCQ), Cloze Deletions, Image Occlusion (`image_occlusion_canvas.dart`), and LaTeX Rich Cards.
  * **Study Modes**: Normal FSRS review, Remedial Cram mode, Sprint Rush, and Offline Flashcard Generation.
  * **CRDT Deck Merging** (`crdt_deck_merger.dart`): Conflict-free resolution for multi-device deck updates.
  * **Thought Parking Lot** (`thought_parking_lot_sheet.dart`): Quick drawer to jot down side thoughts during intense study without breaking focus.
  * **Audio Pronunciation** (`audio_pronounce_button.dart`): Text-to-speech rendering for foreign language and term learning.

* **Detailed File & Symbol Structure**:
  * **Presentation Pages**:
    * `decks_page.dart`: Primary deck library with search, tags, and progress meters.
    * `create_deck_page.dart`: Deck creator with subdeck hierarchy configuration.
    * `study_session_page.dart`: Interactive card flip canvas with FSRS rating buttons (Again, Hard, Good, Easy).
    * `focus_workspace_page.dart`: Distraction-free study workspace with ambient sounds and focus timer.
    * `session_summary_page.dart`: End-of-session breakdown with retention graph, accuracy percentage, and XP rewards.
    * `offline_flashcard_generation_page.dart`: On-device AI card synthesis.
  * **State Management**:
    * `decks_bloc.dart`: Library-level deck operations.
    * `study_session_cubit.dart`: Handles active study session state, card queues, and timer ticks.
    * `focus_session_cubit.dart`: Controls Pomodoro/focus session states.
  * **Domain Algorithms & Services**:
    * `fsrs_algorithm_engine.dart`: Mathematical implementation of memory decay formulas.
    * `fsrs_scheduler.dart`: Card scheduling queue logic.
    * `crdt_deck_merger.dart`: Operational transformation/CRDT merge logic.
    * `card_similarity_checker.dart`: Prevents duplicate card creation in a deck.
    * `study_engine_router.dart`: Routes study sessions to correct review queues.
  * **Key Widgets**:
    * `flashcard_gesture_canvas.dart`, `fsrs_rating_action_bar.dart`, `fsrs_retrievability_visualizer.dart`, `image_occlusion_canvas.dart`, `image_occlusion_card_viewer.dart`, `latex_card_content_viewer.dart`, `subdeck_hierarchy_tree.dart`, `thought_parking_lot_sheet.dart`.

---

### 2.5. Deck Marketplace (`deck_marketplace`)

Community discovery platform allowing users to share, publish, browse, and clone high-quality study decks.

* **Primary Capabilities**:
  * Browse curated public flashcard decks by subject, academic level, and exam type.
  * One-tap deck cloning (`clone_shared_deck_use_case.dart`) into local study workspace.
  * Deck publishing sheet with license settings, tags, and sample preview cards.

* **Detailed File & Symbol Structure**:
  * **Presentation Pages**: `deck_marketplace_detail_page.dart`.
  * **Widgets**: `marketplace_deck_card.dart`, `publish_deck_modal_sheet.dart`.
  * **Use Cases**: `clone_shared_deck_use_case.dart`.
  * **Entities & Models**: `shared_deck_entity.dart`, `shared_deck_model.dart`.

---

### 2.6. Syllabot AI Tutor & RAG Engine (`syllabot`)

Context-aware AI study assistant supporting hybrid local/cloud LLM inference, Socratic guidance, document Q&A, text-to-speech/speech-to-text, and direct deck creation from chat.

* **Primary Capabilities**:
  * **Hybrid Execution Engine Router** (`execution_engine_router.dart`): Routes prompts between Cloud Gemini 1.5/2.0 API (`syllabot_remote_data_source.dart`) and On-Device Local LLM (`local_llm_engine_client.dart`).
  * **Socratic Study Mode** (`socratic_mode_selector.dart`): Configures Syllabot to guide students with step-by-step hints rather than giving direct answers.
  * **Retrieval-Augmented Generation (RAG)**: Queries vector embeddings of uploaded course documents (`vector_search_client.dart`) and displays inline citation badges (`rag_reference_badge.dart`).
  * **Interactive LaTeX Scratchpad** (`chat_latex_scratchpad_widget.dart`): Render and edit complex mathematical derivations directly within chat.
  * **Voice Dialogue Modal** (`voice_dialogue_modal.dart`): Hands-free voice conversation with real-time speech normalization and animated audio waveforms.
  * **Chat-to-Deck Generator** (`generate_deck_from_chat_use_case.dart`): Converts AI explanatory conversations directly into flashcard decks.

* **Detailed File & Symbol Structure**:
  * **Presentation Pages**:
    * `syllabot_chat_page.dart`: Modern conversational interface with streaming markdown/LaTeX rendering.
  * **State Management**:
    * `syllabot_chat_bloc.dart`, `syllabot_chat_event.dart`, `syllabot_chat_state.dart`: Controls message streaming, chunking, audio input, and RAG context injection.
  * **Domain Layer**:
    * **Use Cases**: `stream_syllabot_response_use_case.dart`, `query_document_context_use_case.dart`, `generate_deck_from_chat_use_case.dart`, `generate_document_embeddings_use_case.dart`, `get_chat_history_use_case.dart`, `purge_expired_ai_cache_use_case.dart`.
    * **Entities**: `chat_message_entity.dart`, `conversation_session_entity.dart`, `document_chunk_entity.dart`, `execution_engine_type.dart`, `socratic_mode.dart`.
  * **UI Widgets**:
    * `syllabot_chat_input_bar.dart`, `chat_bubble_widget.dart`, `audio_input_waveform_button.dart`, `voice_dialogue_modal.dart`, `rag_reference_badge.dart`, `rag_source_inspection_sheet.dart`, `local_llm_download_bar.dart`, `chat_latex_scratchpad_widget.dart`.
  * **Data Layer Clients**:
    * `syllabot_api_client.dart`, `vector_search_client.dart`, `local_llm_engine_client.dart`, `rag_remote_data_source_impl.dart`.

---

### 2.7. Interactive Quiz & Past Questions System (`quiz`)

Comprehensive examination prep engine featuring real past exam questions (WAEC, JAMB, UTME, NECO, POST-UTME), Computer-Based Test (CBT) simulations, multiplayer 1v1 Quiz Duels, and a "Who Wants to Be a Millionaire" academic game mode.

* **Primary Capabilities**:
  * **CBT Examination Workspace**: Simulated timed exam environment with question flagging, calculator, formulas viewer, and answer grid.
  * **Past Questions Board**: Filter past questions by year, subject, exam body, and difficulty with detailed AI-generated explanations.
  * **1v1 Real-Time Quiz Duel Arena** (`quiz_duel_arena_page.dart`): Synchronized multiplayer quiz battles via WebSockets (`quiz_duel_websocket_client.dart`) with ELO ranking tiers (`quiz_duel_elo_tier.dart`).
  * **Academic Millionaire Arcade**: "Who Wants to Be a Millionaire" gamified quiz mode featuring Audience Poll lifeline (`millionaire_audience_poll_dialog.dart`), 50:50, Phone-a-Friend, and ladder navigation (`millionaire_ladder_drawer.dart`).
  * **Failed Quiz to Deck Converter** (`convert_failed_quiz_to_deck_use_case.dart`): Automatically extracts incorrectly answered quiz items into a targeted remedial flashcard deck.

* **Detailed File & Symbol Structure**:
  * **Presentation Pages**:
    * `quiz_workspace_page.dart`: Active test session UI.
    * `past_questions_board_page.dart`: Browsable archive of official national/international exam questions.
    * `course_questions_page.dart`: Subject-specific practice questions.
    * `quiz_duel_arena_page.dart`: Real-time multiplayer battle arena.
    * `quiz_results_page.dart`: Diagnostic performance breakdown with grade evaluation (`academic_grade_evaluator.dart`).
  * **State Management**:
    * `quiz_session_cubit.dart`, `quiz_session_state.dart`: Manages CBT timer, selected options, and submission logic.
    * `quiz_duel_cubit.dart`, `quiz_duel_state.dart`: Controls matchmaking, turn synchronization, and live scoreboard.
    * `past_questions_bloc.dart`, `past_questions_event.dart`, `past_questions_state.dart`.
  * **Domain Logic & Engines**:
    * `academic_grade_evaluator.dart`: Calculates letter grades, percentile ranks, and weak topic clusters.
    * `millionaire_tiering_engine.dart`: Governs cash/XP rewards and question scaling in Millionaire mode.
    * `formula_aware_text_formatter.dart` & `quiz_content_sanitizer.dart`: Clean formatting of math equations and code snippets.
  * **Widgets**:
    * `mcq_option_card.dart`, `latex_rich_viewer.dart`, `explanation_accordion.dart`, `cbt_practice_config_modal_sheet.dart`, `quiz_duel_matchmaking_sheet.dart`, `quiz_duel_leaderboard_sheet.dart`, `millionaire_lifeline_bar.dart`, `quiz_audio_reader_button.dart`.

---

### 2.8. Real-Time Live Study & Focus Rooms (`study_rooms`)

Collaborative study spaces supporting WebRTC live audio channels, shared whiteboard canvas, ephemeral member presence, focus session timers, and floating reactions.

* **Primary Capabilities**:
  * **LiveKit Audio Integration** (`livekit_audio_service_impl.dart`): Low-latency voice channels for study groups.
  * **Real-time Ephemeral Presence** (`ephemeral_presence_client.dart`): Multi-user avatar status, active focus states, and mute indicators.
  * **Collaborative Whiteboard Canvas** (`whiteboard_canvas_widget.dart`): Interactive canvas with vector compression (`whiteboard_compression.dart`) for remote problem-solving.
  * **In-Room Deck Study Workspace** (`in_room_deck_study_workspace.dart`): Shared flashcard deck sessions where room members study together in real time.
  * **Floating Reaction Overlay** (`floating_reaction_overlay.dart`): Animated emoji bursts across room screens.

* **Detailed File & Symbol Structure**:
  * **Presentation Pages**:
    * `study_hub_page.dart`: Directory of active live focus rooms and study circles.
    * `live_study_room_page.dart`: Active room view with voice controls, participant grid, chat drawer, and whiteboard.
  * **State Management**:
    * `live_room_cubit.dart`: Manages WebRTC audio connections, presence updates, and room tools.
  * **Domain Layer**:
    * **Use Cases**: `join_live_study_room_use_case.dart`.
    * **Services**: `livekit_audio_service.dart`, `whiteboard_compression.dart`.
    * **Entities**: `study_room_entity.dart`, `study_circle_entity.dart`, `room_member_presence.dart`.
  * **UI Widgets**:
    * `live_focus_room_card.dart`, `study_circle_card.dart`, `create_study_room_sheet.dart`, `create_study_circle_sheet.dart`, `room_chat_drawer.dart`, `voice_note_player_widget.dart`, `focus_session_summary_sheet.dart`.

---

### 2.9. Community Hub & Peer Forums (`community`)

Automated course community provision, peer discussion forums, Socratic automated hints, content moderation, and audio spoken math conversion.

* **Primary Capabilities**:
  * Auto-provisioned communities (`auto_provision_community_use_case.dart`) tied to specific academic courses or exams.
  * Discussion threads with rich media attachments (images, LaTeX snippets, voice notes).
  * Automated Socratic hint generation (`forum_socratic_hint_service.dart`) that detects homework questions and provides guided hints instead of answers.
  * Content moderation pipeline (`content_moderation_service.dart`) with user flagging (`report_content_modal_sheet.dart`).
  * Spoken Math Converter (`spoken_math_converter.dart`): Converts LaTeX math expressions into natural human speech for audio accessibility.

* **Detailed File & Symbol Structure**:
  * **Presentation Pages**:
    * `community_hub_page.dart`: Community feed, course channels, and trending discussions.
    * `create_forum_discussion_page.dart`: Rich text & math thread authoring screen.
    * `forum_thread_detail_page.dart`: Thread view with nested replies and Socratic hint accordions.
  * **State Management**:
    * `community_hub_bloc.dart`, `community_event.dart`, `community_state.dart`.
    * `auto_community_cubit.dart`, `auto_community_state.dart`.
  * **Domain Services**:
    * `forum_socratic_hint_service.dart`, `content_moderation_service.dart`, `spoken_math_converter.dart`.
  * **Widgets**:
    * `community_forum_feed_list.dart`, `track_forum_post_card.dart`, `socratic_hint_accordion_widget.dart`, `expandable_create_post_fab.dart`, `community_pulse_banner.dart`, `forum_media_attachment_card.dart`.

---

### 2.10. Dashboard & CBT Readiness Analytics (`dashboard`)

Central command center providing real-time cognitive readiness gauges, Ebbinghaus retention decay charts, streak tracking, and course module catalogs.

* **Primary Capabilities**:
  * **CBT Readiness Gauge** (`cbt_readiness_calculator.dart`): Algorithmic assessment predicting exam success probability based on recall speed, question difficulty, and FSRS retrievability.
  * **Ebbinghaus Memory Decay Chart** (`ebbinghaus_decay_calculator.dart` & `adaptive_retention_chart.dart`): Visualizes projected knowledge retention curves over 30 days.
  * **Activity Heatmap** (`study_activity_heatmap.dart`): GitHub-style daily study intensity matrix.
  * **Streak Shield Protection** (`streak_shield_indicator.dart`): Visual indicator of streak freezes and active study streaks.
  * **Auto-Curated Course Modules** (`auto_curate_exam_courses_use_case.dart`): Dynamically structures course materials according to target exam dates.

* **Detailed File & Symbol Structure**:
  * **Presentation Pages**:
    * `dashboard_page.dart`: Main landing hub after authentication.
    * `analytics_detail_page.dart`: Deep-dive metrics on study time, accuracy, and topic mastery.
    * `course_module_page.dart` & `curate_courses_page.dart`: Course curriculum browser.
    * `all_curated_courses_page.dart` & `mock_exam_lobby_page.dart`.
  * **State Management**:
    * `dashboard_bloc.dart`, `dashboard_event.dart`, `dashboard_state.dart`.
    * `curate_courses_cubit.dart`, `curate_courses_state.dart`.
  * **Domain Logic & Calculators**:
    * `cbt_readiness_calculator.dart`, `ebbinghaus_decay_calculator.dart`, `subject_catalog.dart`.
  * **Key UI Widgets**:
    * `cbt_readiness_gauge_card.dart`, `adaptive_retention_chart.dart`, `study_activity_heatmap.dart`, `retention_heat_map_widget.dart`, `curated_course_carousel.dart`, `streak_shield_indicator.dart`, `syllabot_quick_prompt_bar.dart`, `millionaire_arcade_banner.dart`.

---

### 2.11. Exam Timetable & Cram Planner (`planner`)

Smart countdown timer and daily study workload optimizer designed to maximize recall prior to major examinations.

* **Primary Capabilities**:
  * **Cram Workload Calculator** (`cram_workload_calculator.dart`): Computes necessary daily card reviews and quiz practice counts based on days remaining until exam.
  * **Exam Countdown Banners**: Real-time ticker showing exact days/hours until scheduled tests.
  * **Syllabus Checklist**: Interactive syllabus tracking allowing users to mark off completed topics.

* **Detailed File & Symbol Structure**:
  * **Presentation Pages**: `exam_timetable_page.dart`.
  * **State Management**: `cram_planner_cubit.dart`, `cram_planner_state.dart`.
  * **Use Cases**: `calculate_daily_cram_target_use_case.dart`, `create_exam_countdown_use_case.dart`.
  * **Widgets**: `exam_countdown_banner.dart`, `study_calibration_graph_widget.dart`, `syllabus_checklist_widget.dart`, `add_exam_modal_sheet.dart`, `manage_exam_modal_sheet.dart`, `postpone_exam_modal_sheet.dart`.

---

### 2.12. Gamification & Global Leaderboard (`leaderboard`)

Competitive league system encouraging consistent study habits through XP ranking, podium tier rewards, and streak shields.

* **Primary Capabilities**:
  * Real-time global and course-level rankings (`stream_leaderboard_rankings_use_case.dart`).
  * Podium display for top scholars (`leaderboard_podium_widget.dart`).
  * Tier promotion celebrations (`tier_promotion_celebration_modal.dart`) with animation effects.
  * Streak freeze shields to protect progress during breaks.

* **Detailed File & Symbol Structure**:
  * **Presentation Pages**: `leaderboard_page.dart`.
  * **Widgets**: `leaderboard_podium_widget.dart`, `leaderboard_rank_card.dart`, `leaderboard_hero_tier_card.dart`, `leaderboard_floating_hud.dart`, `streak_leaderboard_widget.dart`, `tier_promotion_celebration_modal.dart`, `streak_freeze_shield_sheet.dart`.

---

### 2.13. User Profile & Security Management (`profile`)

User account management, notification preferences, multi-factor authentication (MFA/2FA) setup, active session management, and AI settings.

* **Primary Capabilities**:
  * Display name, avatar upload, and security credential updates.
  * 2FA setup screen with TOTP QR code enrollment (`two_factor_setup_page.dart`).
  * Active sessions manager (`active_sessions_list_widget.dart`) allowing remote logout of other devices.
  * Syllabot AI customized behavior preferences (`syllabot_ai_settings_page.dart`).

* **Detailed File & Symbol Structure**:
  * **Presentation Pages**: `profile_page.dart`, `security_settings_page.dart`, `app_preferences_page.dart`, `academic_track_settings_page.dart`, `syllabot_ai_settings_page.dart`, `two_factor_setup_page.dart`, `about_support_page.dart`.
  * **Use Cases**: `profile_security_use_cases.dart`, `notification_preferences_use_cases.dart`, `update_avatar_use_case.dart`, `update_display_name_use_case.dart`, `update_password_use_case.dart`, `send_password_reset_email_use_case.dart`.
  * **Widgets**: `active_sessions_list_widget.dart`, `study_statistics_summary_card.dart`.

---

### 2.14. Monetization & Subscriptions (`monetization`)

In-app billing and premium tier entitlement management powered by RevenueCat SDK and backend promo code redemption.

* **Primary Capabilities**:
  * RevenueCat integration (`revenuecat_service.dart`) for managing Pro subscriptions.
  * `SubscriptionGuard`: Domain service enforcing feature gates for free vs. Pro users.
  * Custom promo code redemption modal (`promo_code_modal_sheet.dart`).

* **Detailed File & Symbol Structure**:
  * **Presentation Screens**: `paywall_screen.dart`.
  * **Services**: `subscription_guard.dart`, `revenuecat_service.dart`.
  * **Use Cases**: `redeem_promo_code_use_case.dart`.
  * **Widgets**: `promo_code_bottom_sheet.dart`, `promo_code_modal_sheet.dart`.

---

### 2.15. Notifications (`notifications`)

In-app notification inbox and push notification routing for study reminders, streak warnings, duel invitations, and forum activity.

* **Detailed File & Symbol Structure**:
  * **Pages**: `notifications_page.dart`.
  * **State**: `notifications_cubit.dart`, `notifications_state.dart`.
  * **Widgets**: `notification_tile.dart`.
  * **Entities**: `notification_item_entity.dart`.

---

### 2.16. Experimental On-Device Offline AI (`offline_ai`)

Local LLM isolate manager enabling full AI flashcard synthesis and offline tutoring without active internet connection.

* **Primary Capabilities**:
  * `local_inference_isolate_manager.dart`: Spawns and manages a dedicated Dart isolate for running GGML/GGUF local quantized AI models.
  * `experimental_offline_guard.dart`: Checks device memory (RAM) and CPU hardware capability before loading heavy local models.

---

## 3. Core Platform Infrastructure & Shared Services

### 3.1. Local Database & Sync Engine (`lib/src/core`)
* **Drift Local SQLite DB** (`database/app_database.dart` & `tables.dart`): Persistent local database powering offline-first functionality for decks, flashcards, study sessions, and offline AI logs.
* **App Sync Engine** (`sync/app_sync_engine.dart`): Manages bi-directional syncing between local SQLite database and cloud Supabase backend with conflict management.
* **Network Stack** (`networking/`): Built on Dio with response logging, JWT bearer token auto-refresh interceptors, verified SSL certificate pinning, and real-time socket connections.
* **Neural Palette & Liquid Theme System** (`themes/`): Custom Dark/Light theme presets (`neural_palette.dart`, `app_theme.dart`) with dynamic glassmorphism properties.

### 3.2. Shared System Utilities & Export Engine (`lib/src/shared`)
* **Multi-Format Export Engine** (`export/`):
  * `anki_export_service.dart`: Compiles decks into native `.apkg` files for Anki compatibility.
  * `notion_csv_formatter.dart`: Formats study materials for Notion imports.
  * `pdf_printable_generator.dart`: Generates print-ready PDF study guides and flashcard sheets.
* **Hardware Performance Benchmark** (`hardware/services/device_performance_benchmark.dart`): Measures device CPU/GPU throughput to dynamically adjust background visual effects and local LLM sizes.
* **Shared UI Components** (`widgets/`):
  * `biometric_lock_overlay.dart` & `tailored_biometric_lock_view.dart`: Instant security overlay when switching apps.
  * `app_liquid_glass_tab_bar.dart` & `app_liquid_card.dart`: Custom glassmorphic navigation and card UI components.
  * `floating_syllabot_overlay.dart`: Persistent floating AI bubble accessible anywhere in the app.
  * `gratification_celebration_overlay.dart`: Confetti and particle system for study streak milestones.

---

## 4. Supabase Backend Edge Functions & Microservices

Located in `supabase/functions/`, these TypeScript serverless microservices power heavy compute, AI streaming, real-time audio tokens, and external webhooks.

| Function Directory | Purpose & Key Operations |
| :--- | :--- |
| `syllabot-stream/` | Streams Syllabot AI responses using SSE (Server-Sent Events) with semantic caching (`semantic_cache_provider.ts`) and custom router. |
| `process-document-ingestion/` | Asynchronous cloud document parser processing uploaded PDFs/PPTX files with markdown chunking (`markdown_chunker.ts`). |
| `generate-flashcards-stream/` | Streams AI flashcard synthesis directly to client during document upload. |
| `parse-stem-ocr/` | Specialized OCR pipeline processing handwritten mathematical equations and physics diagrams into LaTeX AST syntax. |
| `generate-quiz-questions/` | AI question generator creating CBT questions tailored to specific syllabi and difficulty levels. |
| `calculate-leaderboard/` | Cron-triggered serverless job computing weekly global rankings, XP totals, and league promotions. |
| `revenuecat-webhook/` | Handles real-time billing webhooks from RevenueCat to update subscription entitlements in Supabase DB. |
| `generate-livekit-token/` | Generates secure access tokens for client connection to LiveKit WebRTC audio rooms. |
| `presence-heartbeat/` | Manages live study room member presence and auto-evicts inactive connections. |
| `provision-course-community/` | Automatically provisions discussion forums and chat channels for newly enrolled courses. |
| `upload-forum-media/` | Secure media ingestion and virus/content scanning for forum attachments. |
| `trigger-notifications/` & `send-push-notification/` | Dispatcher for Firebase Cloud Messaging (FCM) push notifications. |
| `generate-embeddings/` | Computes vector embeddings for text chunks using OpenAI/Gemini embedding models. |
| `get-admin-leads/` & `verify-admin-token/` | Administrative backend endpoints for telemetry and user management. |
| `cleanup-ai-sessions/` | Maintenance worker clearing expired AI response caches and temporary upload buffers. |

---

## 5. Automation, Seeding & Tooling Scripts

Found in `scripts/`, `tool/`, and root level:

* `ollama_fallback_generator.py`: Local developer utility for testing offline AI flashcard synthesis via local Ollama instances.
* `scripts/seed_forum_discussions.py`: Database populator creating realistic peer study discussions for testing.
* `scripts/sync_myschool_subjects.py`: Subject and past question database synchronizer.
* `scripts/export_leads.py`: Analytics telemetry data exporter.
* `scripts/crawler/`: Custom Python scraper built with BeautifulSoup4 for scraping academic syllabus requirements.
* `scripts/deploy_production.sh`: Shell script for building and deploying Flutter releases and Supabase Edge Functions.

---

## Summary Matrix of Project Features

| Feature | Primary Folder | Key Tech Stack |
| :--- | :--- | :--- |
| **Authentication & Identity** | `lib/src/features/auth` | Supabase Auth, Biometrics, OAuth |
| **Academic Calibration** | `lib/src/features/onboarding_calibration` | BLoC, Custom Curriculum Resolver |
| **Document Ingestion & OCR** | `lib/src/features/ingestion` | ML Kit OCR, Deep Dedup, Chunking |
| **Flashcards & FSRS Study** | `lib/src/features/decks` | FSRS-v4 Algorithm, Drift DB, Image Occlusion |
| **Deck Marketplace** | `lib/src/features/deck_marketplace` | Public Repositories, One-tap Cloning |
| **Syllabot AI Tutor & RAG** | `lib/src/features/syllabot` | Cloud/Local Hybrid LLM, Vector RAG, Socratic Engine |
| **CBT & Past Questions** | `lib/src/features/quiz` | CBT Timer, Millionaire Arcade, 1v1 WebSocket Duels |
| **Live Focus Study Rooms** | `lib/src/features/study_rooms` | LiveKit WebRTC Audio, Shared Whiteboard, Presence |
| **Community Forums** | `lib/src/features/community` | Auto-provisioned Channels, Socratic Hint AI |
| **CBT Readiness Analytics** | `lib/src/features/dashboard` | Ebbinghaus Decay Curve, Readiness Gauge |
| **Exam Timetable & Planner** | `lib/src/features/planner` | Workload Calculator, Countdown Banners |
| **Gamified Leaderboard** | `lib/src/features/leaderboard` | Real-time Rankings, Tier Promotions, Streak Freeze |
| **User Profile & Security** | `lib/src/features/profile` | 2FA TOTP Setup, Session Revocation |
| **Monetization Engine** | `lib/src/features/monetization` | RevenueCat SDK, Subscription Guards |
| **Multi-Format Deck Exporter** | `lib/src/shared/export` | Native Anki `.apkg`, Notion CSV, Printable PDF |
| **Edge Functions Backend** | `supabase/functions/` | TypeScript, Deno, SSE Streams, Vector Embeddings |
