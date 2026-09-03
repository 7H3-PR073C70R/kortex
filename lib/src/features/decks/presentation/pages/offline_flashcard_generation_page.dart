import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/decks/data/services/offline_model_installer.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

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
  final List<GeneratedFlashcard> _cards = [];
  StudyEngineExecutionMode _currentMode =
      StudyEngineExecutionMode.offlineOnDevice;

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
    final mode = await _engineRouter.getExecutionMode();
    if (mounted) {
      setState(() {
        _isModelReady = installed;
        _currentMode = mode;
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Offline AI Study Cards',
          style: typography.headline.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 18.sp,
          ),
        ),
        actions: [
          _buildModeBadge(colors, typography),
          SizedBox(width: 16.w),
        ],
      ),
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
                Text(
                  'Generated Cards (${_cards.length})',
                  style: typography.headline.semiBold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 16.sp,
                  ),
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

  Widget _buildModeBadge(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
  ) {
    final isOffline = _currentMode == StudyEngineExecutionMode.offlineOnDevice;
    final badgeColor = isOffline ? colors.syllabotAccent : colors.success;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(40),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: badgeColor,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOffline ? Icons.offline_bolt : Icons.cloud_done,
            size: 14.sp,
            color: badgeColor,
          ),
          SizedBox(width: 4.w),
          Text(
            isOffline ? 'Local Fllama' : 'Cloud Online',
            style: typography.caption.bold.copyWith(
              color: badgeColor,
              fontSize: 12.sp,
            ),
          ),
        ],
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
                      color: Colors.white,
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
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
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
