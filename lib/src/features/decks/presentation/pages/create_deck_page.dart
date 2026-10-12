import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/create_deck_action_coordinator.dart';
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/create_deck_ai_generator_tab.dart';
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/create_deck_cards_river.dart';
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/create_deck_details_card.dart';
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/create_deck_manual_entry_tab.dart';
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/create_deck_past_questions_tab.dart';
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/create_deck_upload_notes_tab.dart';
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/draft_card.dart';
import 'package:kortex/src/features/ingestion/data/services/local_ingestion_service.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';

@RoutePage()
class CreateDeckPage extends HookWidget {
  const CreateDeckPage({
    this.courseId,
    this.courseCode,
    this.courseTitle,
    this.mappedSubject,
    this.decksRepository,
    this.userActivityService,
    this.decksBloc,
    this.dashboardBloc,
    this.studyEngineRouter,
    this.ingestionService,
    this.filePickerService,
    this.coordinator,
    super.key,
  });

  final String? courseId;
  final String? courseCode;
  final String? courseTitle;
  final String? mappedSubject;
  final DecksRepository? decksRepository;
  final UserActivityService? userActivityService;
  final DecksBloc? decksBloc;
  final DashboardBloc? dashboardBloc;
  final StudyEngineRouter? studyEngineRouter;
  final LocalIngestionService? ingestionService;
  final FilePickerService? filePickerService;
  final CreateDeckActionCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final resolvedSubject =
        courseTitle ?? mappedSubject ?? courseCode ?? 'General Studies';
    final resolvedCourseCode = courseCode ?? 'GEN';

    final effectiveCoordinator = useMemoized(
      () =>
          coordinator ??
          CreateDeckActionCoordinator(
            decksRepository: decksRepository,
            userActivityService: userActivityService,
            decksBloc: decksBloc,
            dashboardBloc: dashboardBloc,
            studyEngineRouter: studyEngineRouter,
            ingestionService: ingestionService,
            filePickerService: filePickerService,
          ),
      [
        coordinator,
        decksRepository,
        userActivityService,
        decksBloc,
        dashboardBloc,
        studyEngineRouter,
        ingestionService,
        filePickerService,
      ],
    );

    final selectedTabIndex = useState<int>(0); // 0: Manual, 1: AI Prompt, 2: Notes, 3: Past Questions

    final titleController = useTextEditingController(
      text: courseCode != null && courseCode!.isNotEmpty
          ? '$courseCode Study Deck'
          : 'New Study Deck',
    );
    final descController = useTextEditingController();

    // Deck Cards List
    final deckCards = useState<List<DraftCard>>([]);

    // Manual Card Entry
    final manualFrontController = useTextEditingController();
    final manualBackController = useTextEditingController();

    // AI Generation State
    final aiTopicController = useTextEditingController(
      text: courseTitle ?? resolvedCourseCode,
    );
    final aiCardCount = useState<int>(10);
    final isAiGenerating = useState<bool>(false);

    // Document Ingestion State
    final pickedDoc = useState<PickedDocument?>(null);
    final isDocIngesting = useState<bool>(false);
    final docStatus = useState<String>('');

    final isSaving = useState<bool>(false);

    // Add manual card to deck
    void addManualCard() {
      final front = manualFrontController.text.trim();
      final back = manualBackController.text.trim();

      if (front.isEmpty || back.isEmpty) {
        context.showSnackBar(
          message: 'Please provide both a Front concept and a Back answer/explanation.',
        );
        return;
      }

      AppFeedback.light();
      deckCards.value = [
        ...deckCards.value,
        DraftCard(front: front, back: back),
      ];
      manualFrontController.clear();
      manualBackController.clear();
    }

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppAdaptiveAppBar(
        backgroundColor: colors.backgroundPrimary,
        title: Column(
          children: [
            Text(
              'Create Study Deck',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 17,
              ),
            ),
            if (courseCode != null)
              Text(
                '$courseCode • $resolvedSubject',
                style: typography.footnote.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
          ],
        ),
        breadcrumbs: [
          AppBreadcrumbItem(
            label: 'Decks',
            onTap: () => context.router.maybePop(),
          ),
          const AppBreadcrumbItem(label: 'Create Study Deck'),
        ],
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => context.router.maybePop(),
              child: Text(
                'Cancel',
                style: typography.subhead.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CreateDeckDetailsCard(
                          titleController: titleController,
                          descController: descController,
                          courseCode: resolvedCourseCode,
                        ),
                        const SizedBox(height: 20),
                        AppLiquidGlassTabBar(
                          tabs: const [
                            'Manual Cards',
                            'AI Generator',
                            'Upload Notes',
                            'Past Questions',
                          ],
                          selectedIndex: selectedTabIndex.value,
                          onTabSelected: (index) {
                            AppFeedback.light();
                            selectedTabIndex.value = index;
                          },
                        ),
                        const SizedBox(height: 18),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOutQuint,
                          switchOutCurve: Curves.easeOut,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0, 0.02),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Column(
                            key: ValueKey<int>(selectedTabIndex.value),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selectedTabIndex.value == 0)
                                CreateDeckManualEntryTab(
                                  frontController: manualFrontController,
                                  backController: manualBackController,
                                  onAddCard: addManualCard,
                                )
                              else if (selectedTabIndex.value == 1)
                                CreateDeckAiGeneratorTab(
                                  topicController: aiTopicController,
                                  cardCount: aiCardCount.value,
                                  onCardCountChanged: (count) =>
                                      aiCardCount.value = count,
                                  isGenerating: isAiGenerating.value,
                                  onGenerate: () =>
                                      effectiveCoordinator.generateCardsWithAi(
                                        context: context,
                                        topic: aiTopicController.text,
                                        resolvedCourseCode: resolvedCourseCode,
                                        cardCount: aiCardCount.value,
                                        isAiGenerating: isAiGenerating,
                                        deckCards: deckCards,
                                      ),
                                )
                              else if (selectedTabIndex.value == 2)
                                CreateDeckUploadNotesTab(
                                  pickedDoc: pickedDoc.value,
                                  isIngesting: isDocIngesting.value,
                                  docStatus: docStatus.value,
                                  onPickDocument: () async {
                                    AppFeedback.light();
                                    final doc = await effectiveCoordinator
                                        .filePickerService
                                        .pickStudyDocument(
                                          extensions: const [
                                            'pdf',
                                            'png',
                                            'jpg',
                                            'jpeg',
                                            'txt',
                                            'pptx',
                                          ],
                                        );
                                    if (doc != null) {
                                      pickedDoc.value = doc;
                                    }
                                  },
                                  onExtractCards: () =>
                                      effectiveCoordinator.ingestDocumentCards(
                                        context: context,
                                        doc: pickedDoc.value,
                                        resolvedCourseCode: resolvedCourseCode,
                                        resolvedSubject: resolvedSubject,
                                        isDocIngesting: isDocIngesting,
                                        docStatus: docStatus,
                                        deckCards: deckCards,
                                      ),
                                )
                              else
                                CreateDeckPastQuestionsTab(
                                  pickedFile: pickedDoc,
                                  isCalibrating: isDocIngesting.value,
                                  docStatus: docStatus.value,
                                  onExecuteCalibration: () =>
                                      effectiveCoordinator.ingestDocumentCards(
                                        context: context,
                                        doc: pickedDoc.value,
                                        resolvedCourseCode: resolvedCourseCode,
                                        resolvedSubject: resolvedSubject,
                                        isDocIngesting: isDocIngesting,
                                        docStatus: docStatus,
                                        deckCards: deckCards,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        CreateDeckCardsRiver(
                          cards: deckCards.value,
                          onClearAll: () => deckCards.value = [],
                          onDeleteCard: (index) {
                            final list = List<DraftCard>.from(deckCards.value)
                              ..removeAt(index);
                            deckCards.value = list;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                border: Border(
                  top: BorderSide(
                    color: colors.surfaceBorder.withAlpha(isDark ? 40 : 100),
                  ),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: AppButton(
                      text: isSaving.value
                          ? 'Creating Deck...'
                          : 'Create Deck (${deckCards.value.length} Cards)',
                      isLoading: isSaving.value,
                      isEnabled: !isSaving.value && deckCards.value.isNotEmpty,
                      onPressed: isSaving.value
                          ? null
                          : () => effectiveCoordinator.saveDeck(
                                context: context,
                                title: titleController.text,
                                description: descController.text,
                                courseId: courseId,
                                resolvedCourseCode: resolvedCourseCode,
                                resolvedSubject: resolvedSubject,
                                cards: deckCards.value,
                                isSaving: isSaving,
                              ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
