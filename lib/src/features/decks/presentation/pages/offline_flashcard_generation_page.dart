import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/core/themes/color/app_material_colors.dart';
import 'package:kortex/src/features/decks/data/services/offline_model_installer.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/l10n/l10n.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.userMessage ??
                  StudyEngineRouter.offlineModelMissingPrompt,
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      } else {
        setState(() {
          _cards.addAll(result.cards);
        });
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.offlineGenNote('$e')),
            backgroundColor: Colors.redAccent,
          ),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          'Offline AI Study Cards',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          _buildModeBadge(),
          SizedBox(width: 16.w),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModelStatusCard(),
              SizedBox(height: 20.h),
              _buildTopicInputCard(),
              SizedBox(height: 24.h),
              if (_isGenerating) _buildGeneratingIndicator(),
              if (_cards.isNotEmpty) ...[
                Text(
                  'Generated Cards (${_cards.length})',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12.h),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _cards.length,
                  separatorBuilder: (_, index) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) =>
                      _buildFlashcardItem(_cards[index]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeBadge() {
    final isOffline =
        _currentMode == StudyEngineExecutionMode.offlineOnDevice;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isOffline
            ? Colors.purpleAccent.withAlpha(51)
            : Colors.greenAccent.withAlpha(51),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isOffline ? Colors.purpleAccent : Colors.greenAccent,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOffline ? Icons.offline_bolt : Icons.cloud_done,
            size: 14.sp,
            color: isOffline ? Colors.purpleAccent : Colors.greenAccent,
          ),
          SizedBox(width: 4.w),
          Text(
            isOffline ? 'Local Fllama' : 'Cloud Online',
            style: TextStyle(
              color: isOffline ? Colors.purpleAccent : Colors.greenAccent,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelStatusCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: _isModelReady
              ? Colors.tealAccent.withAlpha(77)
              : Colors.white12,
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
                color: _isModelReady ? Colors.tealAccent : Colors.orangeAccent,
                size: 22.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  _isModelReady
                      ? 'Local GGUF Model Ready'
                      : 'Offline Model (Qwen-2.5 1.5B)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!_isModelReady && !_isDownloading)
                ElevatedButton(
                  onPressed: _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppMaterialColors.primary,
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  ),
                  child: Text(
                    'Download',
                    style: TextStyle(fontSize: 12.sp, color: Colors.white),
                  ),
                ),
            ],
          ),
          if (_isDownloading) ...[
            SizedBox(height: 12.h),
            LinearProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              backgroundColor: Colors.white10,
              color: Colors.purpleAccent,
            ),
            SizedBox(height: 6.h),
            Text(
              'Downloading weights... '
              '${(_downloadProgress * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
            ),
          ],
          if (_downloadError != null) ...[
            SizedBox(height: 8.h),
            Text(
              _downloadError!,
              style: TextStyle(color: Colors.redAccent, fontSize: 12.sp),
            ),
          ],
          SizedBox(height: 6.h),
          Text(
            'Requirements: 4.0 GB free storage. Wi-Fi required. '
            'Metal / Vulkan accelerated.',
            style: TextStyle(color: Colors.white38, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicInputCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Study Subject / Concept',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: _topicController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Navier-Stokes Equations',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _isGenerating ? null : _generateCards,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              _isGenerating
                  ? 'Synthesizing On-Device...'
                  : 'Generate Flashcards',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingIndicator() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.purpleAccent,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Running local GGUF Metal/Vulkan neural inference...',
              style: TextStyle(color: Colors.white70, fontSize: 13.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcardItem(GeneratedFlashcard card) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: card.isLocalInference
              ? Colors.purpleAccent.withAlpha(77)
              : Colors.blueAccent.withAlpha(77),
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
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              if (card.isLocalInference)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.purple.withAlpha(77),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    'Local Engine',
                    style: TextStyle(
                      color: Colors.purpleAccent,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            card.front,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          Divider(color: Colors.white10, height: 20.h),
          Text(
            'ANSWER & DERIVATION',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: 6.h),
          _renderLatexOrText(card.back),
          if (card.explanation.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              card.explanation,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12.sp,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _renderLatexOrText(String text) {
    if (text.contains(r'$$')) {
      final parts = text.split(r'$$');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: parts.map((part) {
          if (part.trim().isEmpty) return const SizedBox.shrink();
          if (part.contains(r'\')) {
            return Math.tex(
              part.trim(),
              textStyle: TextStyle(fontSize: 14.sp, color: Colors.tealAccent),
            );
          }
          return Text(
            part.trim(),
            style: TextStyle(fontSize: 13.sp, color: Colors.white70),
          );
        }).toList(),
      );
    }
    return Text(
      text,
      style: TextStyle(fontSize: 13.sp, color: Colors.white70),
    );
  }
}
