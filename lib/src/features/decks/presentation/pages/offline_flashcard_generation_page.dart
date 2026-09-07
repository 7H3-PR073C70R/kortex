import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/data/services/offline_model_installer.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class OfflineFlashcardGenerationPage extends StatefulWidget {
  const OfflineFlashcardGenerationPage({
    super.key,
    this.initialTopic = 'Quantum Mechanics & Wave Functions',
  });

  final String initialTopic;

  @override
  State<OfflineFlashcardGenerationPage> createState() =>
      _OfflineFlashcardGenerationPageState();
}

class _OfflineFlashcardGenerationPageState
    extends State<OfflineFlashcardGenerationPage> {
  late final OfflineModelInstaller _installer;
  late final StudyEngineRouter _engineRouter;
  late final TextEditingController _topicController;

  bool _isModelReady = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _downloadError;

  bool _isGenerating = false;
  bool _isSaving = false;
  final List<GeneratedFlashcard> _cards = [];

  @override
  void initState() {
    super.initState();
    _installer = OfflineModelInstaller();
    _engineRouter = StudyEngineRouter(modelInstaller: _installer);
    _topicController = TextEditingController(text: widget.initialTopic);

    unawaited(_checkInitialState());
    _listenToInstallProgress();
  }

  Future<void> _checkInitialState() async {
    final installed = await _installer.isModelInstalled();
    if (mounted) {
      setState(() {
        _isModelReady = installed;
      });
    }
  }

  void _listenToInstallProgress() {
    _installer.progressStream.listen((progress) {
      if (!mounted) return;
      setState(() {
        if (progress.step == InstallerStep.downloading) {
          _isDownloading = true;
          _downloadProgress = progress.progress;
          _downloadError = null;
        } else if (progress.step == InstallerStep.ready) {
          _isDownloading = false;
          _isModelReady = true;
          _downloadProgress = 1;
          _downloadError = null;
        } else if (progress.step == InstallerStep.failed) {
          _isDownloading = false;
          _downloadError = progress.errorMessage;
        } else if (progress.step == InstallerStep.idle) {
          _isDownloading = false;
          _isModelReady = false;
        }
      });
    });
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadError = null;
    });
    await _installer.installModel();
    await _checkInitialState();
  }

  Future<void> _generateCards() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _cards.clear();
    });

    try {
      final result = await _engineRouter.generateStudyPack(
        topic: topic,
        forceOffline: true,
      );

      if (!mounted) return;

      if (result.isOfflineModelMissing) {
        context.showSnackBar(
          message:
              result.userMessage ?? StudyEngineRouter.offlineModelMissingPrompt,
        );
      } else {
        setState(() {
          _cards.addAll(result.cards);
        });
      }
    } on Object catch (e) {
      if (mounted) {
        context.showSnackBar(
          message: context.l10n.offlineGenNote('$e'),
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(_installer.dispose());
    _topicController.dispose();
    super.dispose();
  }

  void _showSaveDeckDialog() {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final defaultTitle = _topicController.text.trim().isNotEmpty
        ? _topicController.text.trim()
        : 'Offline AI Study Deck';
    final titleController = TextEditingController(text: defaultTitle);
    final subjectController = TextEditingController(
      text: _extractSubject(defaultTitle),
    );

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        builder: (sheetContext) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: colors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Text(
                    'Save to Study Decks',
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Save ${_cards.length} generated flashcards to your active recall study deck.',
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  AppTextField(
                    controller: titleController,
                    hintText: 'Deck Title (e.g. $defaultTitle)',
                  ),
                  SizedBox(height: 14.h),
                  AppTextField(
                    controller: subjectController,
                    hintText: 'Subject / Category (e.g. Physics, Mathematics)',
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            side: BorderSide(color: colors.surfaceBorder),
                          ),
                          child: Text(
                            'Cancel',
                            style: typography.body.semiBold.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: AppButton(
                          text: 'Confirm & Save',
                          onPressed: () {
                            final title = titleController.text.trim().isNotEmpty
                                ? titleController.text.trim()
                                : defaultTitle;
                            final subject = subjectController.text.trim().isNotEmpty
                                ? subjectController.text.trim()
                                : 'General Studies';
                            Navigator.of(sheetContext).pop();
                            unawaited(_persistDeck(title: title, subject: subject));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _persistDeck({
    required String title,
    required String subject,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final deckId = UuidUtils.generate();
      final flashcards = _cards.map((c) {
        final explanationText = c.explanation.trim().isNotEmpty
            ? '\n\n💡 Explanation:\n${c.explanation.trim()}'
            : '';
        return FlashcardModel(
          id: UuidUtils.generate(),
          deckId: deckId,
          front: c.front,
          back: '${c.back}$explanationText',
          sourceTopic: subject,
          nextDueDate: DateTime.now(),
        );
      }).toList();

      final deckModel = DeckModel(
        id: deckId,
        title: title,
        subject: subject,
        totalCards: flashcards.length,
        dueCards: flashcards.length,
        masteryRate: 0,
        category: 'Offline AI Study Cards',
        description: 'Synthesized locally using on-device AI for $title.',
        cards: flashcards,
      );

      if (locator.isRegistered<DecksRemoteDataSource>()) {
        await locator<DecksRemoteDataSource>().saveGeneratedDeck(
          deck: deckModel,
          cards: flashcards,
        );
      }

      if (locator.isRegistered<DecksBloc>()) {
        locator<DecksBloc>().add(const DecksRefreshed());
      }
      if (locator.isRegistered<DashboardBloc>()) {
        locator<DashboardBloc>().add(const DashboardRefreshed());
      }

      AppFeedback.light();

      if (!mounted) return;
      context.showSnackBar(
        message: 'Deck "$title" saved to your Study Decks!',
        type: SnackBarType.success,
      );

      unawaited(
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: context.colors.surfacePrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            title: Text(
              'Deck Saved!',
              style: context.typography.title3.bold.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            content: Text(
              'Your ${flashcards.length} flashcards have been added to your active recall queue.',
              style: context.typography.body.regular.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.router.pop();
                },
                child: Text(
                  'Back to Decks',
                  style: context.typography.body.bold.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(
                    context.router.replace(StudySessionRoute(deckId: deckId)),
                  );
                },
                child: Text(
                  'Study Now',
                  style: context.typography.body.bold.copyWith(
                    color: context.colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } on Object catch (e) {
      if (mounted) {
        context.showSnackBar(
          message: 'Failed to save deck: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _extractSubject(String topic) {
    final lower = topic.toLowerCase();
    if (lower.contains('quantum') ||
        lower.contains('physics') ||
        lower.contains('wave') ||
        lower.contains('mechanic')) {
      return 'Physics';
    }
    if (lower.contains('math') ||
        lower.contains('calculus') ||
        lower.contains('algebra') ||
        lower.contains('geometry')) {
      return 'Mathematics';
    }
    if (lower.contains('chem')) return 'Chemistry';
    if (lower.contains('bio')) return 'Biology';
    if (lower.contains('computer') ||
        lower.contains('algorithm') ||
        lower.contains('code')) {
      return 'Computer Science';
    }
    return 'General Studies';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        title: Text(
          'Offline AI Study Cards',
          style: typography.headline.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 18.sp,
          ),
        ),
        actions: [
          if (_cards.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: ShrinkableButton(
                onTap: _showSaveDeckDialog,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withAlpha(isDark ? 80 : 40),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bookmark_add_rounded,
                        color: colors.white,
                        size: 16.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Save Deck',
                        style: typography.caption.bold.copyWith(
                          color: colors.white,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _cards.isNotEmpty
          ? Container(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(240)
                    : colors.surfacePrimary.withAlpha(245),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? colors.surfaceBorderHighlight.withAlpha(60)
                        : colors.surfaceBorder.withAlpha(120),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(isDark ? 60 : 15),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: AppButton(
                  text: 'Save ${_cards.length} Cards as Study Deck',
                  prefixIcon: Icon(
                    Icons.bookmark_add_rounded,
                    color: colors.white,
                    size: 18.sp,
                  ),
                  isLoading: _isSaving,
                  onPressed: _showSaveDeckDialog,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModelStatusCard(colors, typography, isDark),
              SizedBox(height: 20.h),
              _buildTopicInputCard(colors, typography, isDark),
              SizedBox(height: 24.h),
              if (_isGenerating)
                _buildGeneratingIndicator(colors, typography, isDark),
              if (_cards.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Generated Cards (${_cards.length})',
                      style: typography.headline.semiBold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 16.sp,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showSaveDeckDialog,
                      icon: Icon(
                        Icons.bookmark_add_rounded,
                        size: 16.sp,
                        color: colors.primary,
                      ),
                      label: Text(
                        'Save Deck',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _cards.length,
                  separatorBuilder: (_, index) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) => _buildFlashcardItem(
                    _cards[index],
                    colors,
                    typography,
                    isDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelStatusCard(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: _isModelReady
              ? colors.success.withAlpha(90)
              : colors.surfaceBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isModelReady
                    ? Icons.check_circle_outline
                    : Icons.download_for_offline_outlined,
                color: _isModelReady ? colors.success : colors.warning,
                size: 22.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  _isModelReady
                      ? 'Local GGUF Model Ready'
                      : 'Offline Model (Qwen-2.5 1.5B)',
                  style: typography.body.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14.sp,
                  ),
                ),
              ),
              if (!_isModelReady && !_isDownloading)
                ElevatedButton(
                  onPressed: _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                  ),
                  child: Text(
                    'Download',
                    style: typography.caption.bold.copyWith(
                      fontSize: 12.sp,
                      color: colors.white,
                    ),
                  ),
                ),
            ],
          ),
          if (_isDownloading) ...[
            SizedBox(height: 12.h),
            LinearProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              backgroundColor: colors.surfaceBorder,
              color: colors.primary,
            ),
            SizedBox(height: 6.h),
            Text(
              'Downloading weights... '
              '${(_downloadProgress * 100).toStringAsFixed(1)}%',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 12.sp,
              ),
            ),
          ],
          if (_downloadError != null) ...[
            SizedBox(height: 8.h),
            Text(
              _downloadError!,
              style: typography.caption.medium.copyWith(
                color: colors.error,
                fontSize: 12.sp,
              ),
            ),
          ],
          SizedBox(height: 6.h),
          Text(
            'Requirements: 4.0 GB free storage. Wi-Fi required. '
            'Metal / Vulkan accelerated.',
            style: typography.caption.regular.copyWith(
              color: colors.textMuted,
              fontSize: 11.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicInputCard(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: colors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Study Subject / Concept',
            style: typography.subhead.medium.copyWith(
              color: colors.textSecondary,
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 8.h),
          AppTextField(
            controller: _topicController,
            hintText: 'e.g. Navier-Stokes Equations',
          ),
          SizedBox(height: 16.h),
          AppButton(
            text: _isGenerating
                ? 'Synthesizing On-Device...'
                : 'Generate Flashcards',
            isLoading: _isGenerating,
            onPressed: _isGenerating ? null : _generateCards,
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingIndicator(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colors.surfaceBorder),
      ),
      child: Row(
        children: [
          AppLogoLoader(
            size: 20,
            color: colors.primary,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Running local GGUF Metal/Vulkan neural inference...',
              style: typography.body.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcardItem(
    GeneratedFlashcard card,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: card.isLocalInference
              ? colors.primary.withAlpha(80)
              : colors.syllabotAccent.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUESTION',
                style: typography.caption.bold.copyWith(
                  color: colors.textMuted,
                  fontSize: 11.sp,
                  letterSpacing: 1.1,
                ),
              ),
              if (card.isLocalInference)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(50),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    'Local Engine',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            card.front,
            style: typography.body.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 14.sp,
            ),
          ),
          Divider(color: colors.surfaceBorder, height: 20.h),
          Text(
            'ANSWER & DERIVATION',
            style: typography.caption.bold.copyWith(
              color: colors.textMuted,
              fontSize: 11.sp,
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: 6.h),
          _renderLatexOrText(card.back, colors, typography),
          if (card.explanation.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              card.explanation,
              style: typography.footnote.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 12.sp,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _renderLatexOrText(
    String text,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
  ) {
    if (text.contains(r'$$')) {
      final parts = text.split(r'$$');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: parts.map((part) {
          if (part.trim().isEmpty) return const SizedBox.shrink();
          if (part.contains(r'\')) {
            return Math.tex(
              part.trim(),
              textStyle: typography.body.regular.copyWith(
                fontSize: 14.sp,
                color: colors.latexHighlight,
              ),
            );
          }
          return Text(
            part.trim(),
            style: typography.body.regular.copyWith(
              fontSize: 13.sp,
              color: colors.textSecondary,
            ),
          );
        }).toList(),
      );
    }
    return Text(
      text,
      style: typography.body.regular.copyWith(
        fontSize: 13.sp,
        color: colors.textSecondary,
      ),
    );
  }
}
