import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/audio_earcon_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat_bubble_widget.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Interactive dialogue lifecycle states.
enum DialogueState {
  listening,
  thinking,
  speaking,
  idle,
}

/// Industry-standard interactive AI voice dialogue modal.
///
/// Features:
/// - Siri / Gemini fluid multi-color acoustic sound ribbon visualizer (`CustomPainter`).
/// - Strict safe-area protection preventing status bar / Dynamic Island overlap.
/// - Zero-jank GPU-accelerated audio spectrum rendering via [ValueNotifier].
/// - Real-time bidirectional streaming dialogue with natural turn-taking & barge-in.
/// - Adaptive layout responsive across mobile, tablet, desktop, and landscape viewports.
/// - Full keyboard accessibility (Esc to exit, Space to toggle speech).
class VoiceDialogueModal extends StatefulWidget {
  const VoiceDialogueModal({
    required this.ttsHandler,
    this.onSendPrompt,
    this.onStreamPrompt,
    this.initialMode = SocraticMode.stepByStep,
    this.isFullScreenOverlay = false,
    super.key,
  }) : assert(
         onSendPrompt != null || onStreamPrompt != null,
         'Either onSendPrompt or onStreamPrompt must be provided',
       );

  final Future<String> Function(String prompt)? onSendPrompt;
  final Stream<String> Function(String prompt)? onStreamPrompt;
  final TextToSpeechHandler ttsHandler;
  final SocraticMode initialMode;
  final bool isFullScreenOverlay;

  static Future<void> show({
    required BuildContext context,
    required TextToSpeechHandler ttsHandler,
    Future<String> Function(String prompt)? onSendPrompt,
    Stream<String> Function(String prompt)? onStreamPrompt,
    SocraticMode initialMode = SocraticMode.stepByStep,
  }) {
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);
    if (isDesktop) {
      return showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss Voice Dialogue',
        barrierColor: Colors.black.withValues(alpha: 0.75),
        transitionDuration: AppMotion.snappy,
        transitionBuilder: (context, anim1, anim2, child) {
          final curved = AppMotion.easeOutCubic.transform(anim1.value);
          return Transform.scale(
            scale: 0.95 + (0.05 * curved),
            child: Opacity(
              opacity: anim1.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return Material(
            type: MaterialType.transparency,
            child: VoiceDialogueModal(
              onSendPrompt: onSendPrompt,
              onStreamPrompt: onStreamPrompt,
              ttsHandler: ttsHandler,
              initialMode: initialMode,
              isFullScreenOverlay: true,
            ),
          );
        },
      );
    }

    return AppAdaptiveSheet.showModal<void>(
      context: context,
      maxWidth: 620,
      builder: (context) => VoiceDialogueModal(
        onSendPrompt: onSendPrompt,
        onStreamPrompt: onStreamPrompt,
        ttsHandler: ttsHandler,
        initialMode: initialMode,
      ),
    );
  }

  @override
  State<VoiceDialogueModal> createState() => _VoiceDialogueModalState();
}

class _VoiceDialogueModalState extends State<VoiceDialogueModal>
    with SingleTickerProviderStateMixin {
  late final SpeechToTextHandler _sttHandler;
  late final AnimationController _ribbonAnimationController;
  late final AudioEarconService _earconService;

  /// High-performance decibel notifier avoiding full modal rebuilds during mic streaming.
  final ValueNotifier<double> _soundLevelNotifier = ValueNotifier<double>(0);

  DialogueState _state = DialogueState.idle;
  String _liveTranscript = '';
  String _accumulatedTranscript = '';
  String _latestResponse = '';
  late VoiceGender _selectedGender;
  bool _isMuted = false;
  bool _isTranscriptExpanded = false;
  bool _isProcessingPrompt = false;

  Timer? _silenceTimer;
  Timer? _restartListeningTimer;

  static const Duration _silenceThreshold = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _selectedGender = widget.ttsHandler.voiceGender;

    _earconService = locator.isRegistered<AudioEarconService>()
        ? locator<AudioEarconService>()
        : AudioEarconServiceImpl();

    _ribbonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    unawaited(_ribbonAnimationController.repeat());

    _sttHandler = SpeechToTextHandler(
      onResult: (text) {},
      onResultWithFinal: (text, {required isFinal}) {
        if (!mounted || _state != DialogueState.listening) return;
        final words = text.trim();
        if (words.isEmpty) return;

        final fullTranscript = _accumulatedTranscript.isNotEmpty
            ? '$_accumulatedTranscript $words'
            : words;

        setState(() {
          _liveTranscript = fullTranscript;
        });

        if (isFinal) {
          unawaited(_commitVoicePromptImmediately());
        } else {
          _resetSilenceTimer();
        }
      },
      onSoundLevelChange: (level) {
        if (!mounted || _state != DialogueState.listening) return;
        final normalized = ((level + 40.0) / 50.0).clamp(0.0, 1.0);
        if ((normalized - _soundLevelNotifier.value).abs() > 0.02) {
          _soundLevelNotifier.value = normalized;
        }
      },
      onListeningChanged: (listening) {
        if (!mounted) return;
        if (_state == DialogueState.listening && !listening) {
          final prompt = _liveTranscript.trim();
          if (prompt.isNotEmpty) {
            unawaited(_commitVoicePromptImmediately());
          } else {
            setState(() {
              _state = DialogueState.idle;
            });
            _soundLevelNotifier.value = 0;
          }
        }
      },
      onError: (err) {
        if (!mounted) return;
        unawaited(_earconService.playError());
        final errorMsg = 'Microphone error: $err';
        if (_state == DialogueState.listening) {
          setState(() {
            _latestResponse = errorMsg;
            _state = DialogueState.idle;
          });
          _soundLevelNotifier.value = 0;
          if (!_isMuted) {
            unawaited(widget.ttsHandler.speak(errorMsg));
          }
        }
      },
    );

    // Speak initial Syllabot greeting, then start conversational loop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_speakInitialGreeting());
    });
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceThreshold, () {
      if (mounted && _state == DialogueState.listening) {
        unawaited(_onSilenceTimeout());
      }
    });
  }

  Future<void> _onSilenceTimeout() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    if (_state != DialogueState.listening) return;
    await _commitVoicePromptImmediately();
  }

  Future<void> _commitVoicePromptImmediately() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _restartListeningTimer?.cancel();
    _restartListeningTimer = null;
    if (_state != DialogueState.listening || _isProcessingPrompt) return;

    final prompt = _liveTranscript.trim();
    if (prompt.isNotEmpty) {
      setState(() {
        _state = DialogueState.thinking;
      });
      _soundLevelNotifier.value = 0;
      unawaited(_earconService.playProcessingCommit());
      await _sttHandler.stopListening();
      await _processVoicePrompt(prompt);
    } else {
      unawaited(_sttHandler.stopListening());
      if (mounted) {
        setState(() {
          _state = DialogueState.idle;
        });
        _soundLevelNotifier.value = 0;
      }
    }
  }

  Future<void> _speakInitialGreeting() async {
    const greeting =
        "Hello! I'm Syllabot. What topic or problem would you like to explore "
        'together today?';
    if (!mounted) return;
    setState(() {
      _latestResponse = greeting;
      _state = DialogueState.speaking;
    });

    if (!_isMuted) {
      await widget.ttsHandler.speak(greeting);
      await widget.ttsHandler.waitForQueueDrained();
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 1000));
    }

    if (mounted &&
        (_state == DialogueState.speaking || _state == DialogueState.idle)) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted &&
          (_state == DialogueState.speaking || _state == DialogueState.idle)) {
        await _startListening();
      }
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _restartListeningTimer?.cancel();
    _ribbonAnimationController.dispose();
    _soundLevelNotifier.dispose();
    _sttHandler.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _restartListeningTimer?.cancel();
    _restartListeningTimer = null;
    await widget.ttsHandler.stop();
    if (!mounted) return;

    setState(() {
      _state = DialogueState.listening;
      _liveTranscript = '';
      _accumulatedTranscript = '';
    });
    _soundLevelNotifier.value = 0;

    unawaited(_earconService.playListeningStart());
    await _sttHandler.startListening(
      pauseFor: const Duration(milliseconds: 1800),
    );
  }

  Future<void> _processVoicePrompt(String prompt) async {
    if (_isProcessingPrompt) return;
    _isProcessingPrompt = true;
    _silenceTimer?.cancel();
    _silenceTimer = null;

    if (!mounted) {
      _isProcessingPrompt = false;
      return;
    }

    setState(() {
      _state = DialogueState.thinking;
      _latestResponse = '';
    });
    _soundLevelNotifier.value = 0;

    if (!_isMuted) {
      unawaited(widget.ttsHandler.speak('Thinking...'));
    }

    try {
      if (widget.onStreamPrompt != null) {
        final stream = widget.onStreamPrompt!(prompt).timeout(
          const Duration(seconds: 25),
          onTimeout: (sink) {
            sink.addError('Response timeout');
          },
        );
        final sentenceDelimiters = RegExp(r'([.!?\n]+)\s*');
        final clauseDelimiters = RegExp(r'([,;:—–]+)\s*');
        final accumulatedBuffer = StringBuffer();
        var firstSentenceSpoken = false;

        await for (final chunk in stream) {
          if (!mounted || _state == DialogueState.idle) break;
          accumulatedBuffer.write(chunk);
          var accumulated = accumulatedBuffer.toString();

          if (!firstSentenceSpoken) {
            final sentenceMatch = sentenceDelimiters.firstMatch(accumulated);
            final clauseMatch = clauseDelimiters.firstMatch(accumulated);
            final words = accumulated.trim().split(RegExp(r'\s+'));
            final wordCount = words.length;

            int? splitIndex;

            if (sentenceMatch != null) {
              splitIndex = sentenceMatch.end;
            } else if (clauseMatch != null) {
              final textBeforeClause =
                  accumulated.substring(0, clauseMatch.start).trim();
              final clauseWords = textBeforeClause
                  .split(RegExp(r'\s+'))
                  .where((w) => w.isNotEmpty)
                  .length;
              if (clauseWords >= 5) {
                splitIndex = clauseMatch.end;
              }
            } else if (wordCount >= 14) {
              final targetSpaces = words.take(10).join(' ').length;
              splitIndex =
                  targetSpaces < accumulated.length ? targetSpaces : accumulated.length;
            }

            if (splitIndex != null && splitIndex > 0) {
              final firstChunkText = accumulated.substring(0, splitIndex).trim();
              accumulated = accumulated.substring(splitIndex);
              accumulatedBuffer
                ..clear()
                ..write(accumulated);

              if (firstChunkText.isNotEmpty) {
                firstSentenceSpoken = true;
                if (mounted) {
                  setState(() {
                    _state = DialogueState.speaking;
                  });
                  unawaited(_earconService.playSpeakingStart());
                }
                if (!_isMuted) {
                  await widget.ttsHandler.enqueueSentence(firstChunkText);
                }
              }
            }
          } else {
            while (true) {
              final sentenceMatch = sentenceDelimiters.firstMatch(accumulated);
              final clauseMatch = clauseDelimiters.firstMatch(accumulated);
              final words = accumulated.trim().split(RegExp(r'\s+'));
              final wordCount = words.length;

              int? splitIndex;

              if (sentenceMatch != null) {
                splitIndex = sentenceMatch.end;
              } else if (clauseMatch != null) {
                final textBeforeClause =
                    accumulated.substring(0, clauseMatch.start).trim();
                final clauseWords = textBeforeClause
                    .split(RegExp(r'\s+'))
                    .where((w) => w.isNotEmpty)
                    .length;
                if (clauseWords >= 7) {
                  splitIndex = clauseMatch.end;
                }
              } else if (wordCount >= 16) {
                final targetSpaces = words.take(12).join(' ').length;
                splitIndex =
                    targetSpaces < accumulated.length ? targetSpaces : accumulated.length;
              }

              if (splitIndex == null || splitIndex <= 0) break;

              final chunkText = accumulated.substring(0, splitIndex).trim();
              accumulated = accumulated.substring(splitIndex);
              accumulatedBuffer
                ..clear()
                ..write(accumulated);

              if (chunkText.isNotEmpty && !_isMuted) {
                await widget.ttsHandler.enqueueSentence(chunkText);
              }
            }
          }

          if (mounted) {
            setState(() {
              _latestResponse = _latestResponse.isEmpty
                  ? chunk
                  : '$_latestResponse$chunk';
            });
          }
        }

        final remaining = accumulatedBuffer.toString().trim();
        if (remaining.isNotEmpty) {
          if (!firstSentenceSpoken && mounted) {
            setState(() {
              _state = DialogueState.speaking;
            });
          }
          if (!_isMuted) {
            await widget.ttsHandler.enqueueSentence(remaining);
          }
        }

        if (!_isMuted) {
          await widget.ttsHandler.waitForQueueDrained();
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        }

        if (mounted &&
            (_state == DialogueState.speaking ||
                _state == DialogueState.thinking)) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          if (mounted &&
              (_state == DialogueState.speaking ||
                  _state == DialogueState.thinking)) {
            await _startListening();
          }
        }
        return;
      }

      if (widget.onSendPrompt != null) {
        final response = await widget.onSendPrompt!(prompt).timeout(
          const Duration(seconds: 25),
        );
        if (!mounted) return;

        setState(() {
          _latestResponse = response;
          _state = DialogueState.speaking;
        });

        if (!_isMuted) {
          await widget.ttsHandler.speak(response);
          await widget.ttsHandler.waitForQueueDrained();
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 1000));
        }

        if (mounted &&
            (_state == DialogueState.speaking ||
                _state == DialogueState.thinking)) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          if (mounted &&
              (_state == DialogueState.speaking ||
                  _state == DialogueState.thinking)) {
            await _startListening();
          }
        }
      }
    } on Object catch (e) {
      unawaited(_earconService.playError());
      final rawMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      final errorText = rawMsg.isNotEmpty
          ? 'Sorry, an error occurred: $rawMsg'
          : 'Sorry, I ran into an error processing your question. Please try again.';

      if (mounted) {
        setState(() {
          _latestResponse = errorText;
          _state = DialogueState.idle;
        });
        _soundLevelNotifier.value = 0;

        if (!_isMuted) {
          await widget.ttsHandler.speak(errorText);
        }
      }
    } finally {
      _isProcessingPrompt = false;
    }
  }

  void _onInteractionTap() {
    unawaited(HapticFeedback.lightImpact());
    if (_state == DialogueState.listening) {
      if (_liveTranscript.trim().isNotEmpty) {
        unawaited(_commitVoicePromptImmediately());
      } else {
        _silenceTimer?.cancel();
        _silenceTimer = null;
        _restartListeningTimer?.cancel();
        _restartListeningTimer = null;
        setState(() {
          _state = DialogueState.idle;
        });
        _soundLevelNotifier.value = 0;
        unawaited(_sttHandler.stopListening());
      }
    } else if (_state == DialogueState.speaking ||
        _state == DialogueState.thinking) {
      _isProcessingPrompt = false;
      unawaited(widget.ttsHandler.stop());
      unawaited(_startListening());
    } else if (_state == DialogueState.idle) {
      _isProcessingPrompt = false;
      unawaited(_startListening());
    }
  }

  void _toggleGender() {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _selectedGender = _selectedGender == VoiceGender.female
          ? VoiceGender.male
          : VoiceGender.female;
    });
    unawaited(widget.ttsHandler.setVoiceGender(_selectedGender));
  }

  void _toggleMute() {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _isMuted = !_isMuted;
    });
    if (_isMuted) {
      unawaited(widget.ttsHandler.stop());
    }
  }

  void _closeModal() {
    _silenceTimer?.cancel();
    _restartListeningTimer?.cancel();
    unawaited(widget.ttsHandler.stop());
    unawaited(_sttHandler.stopListening());
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDesktop =
        AppAdaptiveSheet.isDesktopOrWeb(context) || widget.isFullScreenOverlay;

    // Primary State Color Tone
    final stateColor = switch (_state) {
      DialogueState.listening => colors.primary,
      DialogueState.speaking => colors.syllabotAccent,
      DialogueState.thinking => colors.warning,
      DialogueState.idle => colors.primary.withValues(alpha: 0.8),
    };

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _closeModal();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _onInteractionTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 680;
          final isLandscape =
              constraints.maxWidth > constraints.maxHeight &&
              constraints.maxHeight < 520;

          if (isDesktop) {
            return Stack(
              children: [
                // Frosted Ambient Backdrop
                GestureDetector(
                  onTap: _closeModal,
                  behavior: HitTestBehavior.opaque,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                // Centered Elevated Glass Shell
                Center(
                  child: Container(
                    width: math.min(constraints.maxWidth - 48, 680),
                    height: math.min(constraints.maxHeight * 0.88, 800),
                    constraints: const BoxConstraints(minHeight: 520),
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: colors.surfaceBorder.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 40,
                          spreadRadius: 4,
                          offset: const Offset(0, 16),
                        ),
                        BoxShadow(
                          color: stateColor.withValues(alpha: 0.12),
                          blurRadius: 60,
                          spreadRadius: -10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: SafeArea(
                        child: _buildModalContent(
                          context,
                          stateColor: stateColor,
                          isDesktop: true,
                          isCompact: isCompact,
                          isLandscape: isLandscape,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Mobile / Adaptive Sheet Presentation with Strict Safe Area Insets
          final mediaQuery = MediaQuery.of(context);
          final windowTopPadding =
              View.of(context).padding.top / View.of(context).devicePixelRatio;
          final topInset = math.max(
            mediaQuery.viewPadding.top,
            math.max(mediaQuery.padding.top, windowTopPadding),
          );

          final windowBottomPadding =
              View.of(context).padding.bottom /
              View.of(context).devicePixelRatio;
          final bottomInset = math.max(
            mediaQuery.viewPadding.bottom,
            math.max(mediaQuery.padding.bottom, windowBottomPadding),
          );

          return Container(
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.dialog),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: topInset > 0 ? topInset + 6 : 12,
                bottom: bottomInset > 0 ? bottomInset + 4 : 12,
              ),
              child: _buildModalContent(
                context,
                stateColor: stateColor,
                isDesktop: false,
                isCompact: isCompact,
                isLandscape: isLandscape,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalContent(
    BuildContext context, {
    required Color stateColor,
    required bool isDesktop,
    required bool isCompact,
    required bool isLandscape,
  }) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Stack(
      children: [
        // Subtle Ambient Radial Aura behind the Ribbon
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.snappyCurve,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 0.75,
                  colors: [
                    stateColor.withValues(alpha: isDark ? 0.18 : 0.09),
                    colors.backgroundPrimary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Primary Modal Layout
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 28 : 20,
            vertical: isDesktop ? 16 : 8,
          ),
          child: Column(
            children: [
              // 2. Adaptive Top Navigation Header (safely below dynamic island)
              _buildHeader(context, isDesktop: isDesktop),

              const SizedBox(height: 8),

              // 3. Main Center Workspace (Landscape Split vs Portrait Stack)
              Expanded(
                child: isLandscape
                    ? _buildLandscapeWorkspace(
                        context,
                        stateColor: stateColor,
                      )
                    : _buildPortraitWorkspace(
                        context,
                        stateColor: stateColor,
                        isCompact: isCompact,
                        isDesktop: isDesktop,
                      ),
              ),

              const SizedBox(height: 10),

              // 4. Floating Interactive Bottom Action Dock
              _buildBottomActionDock(
                context,
                stateColor: stateColor,
                isDesktop: isDesktop,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, {required bool isDesktop}) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left Group: Mode Chip & Branding (Flexible to prevent horizontal overflow)
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: AppRadius.radiusBadge,
              border: Border.all(
                color: colors.primary.withValues(alpha: isDark ? 0.35 : 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  color: colors.primary,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Syllabot Voice',
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.initialMode.label,
                      overflow: TextOverflow.ellipsis,
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Right Group: Voice Persona Controls & Close
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Voice Gender Selector Pill
            PlatformHoverBuilder(
              builder: (context, isHovered, child) {
                return ShrinkableButton(
                  onTap: _toggleGender,
                  child: AnimatedContainer(
                    duration: AppMotion.snappy,
                    curve: AppMotion.snappyCurve,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? colors.primary.withValues(alpha: 0.15)
                          : colors.surfaceSecondary,
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: isHovered
                            ? colors.primary.withValues(alpha: 0.4)
                            : colors.surfaceBorder.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedGender == VoiceGender.female
                              ? Icons.face_3_rounded
                              : Icons.face_6_rounded,
                          color: colors.primary,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedGender == VoiceGender.female
                              ? l10n.voiceGenderFemale
                              : l10n.voiceGenderMale,
                          style: typography.caption.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.swap_horiz_rounded,
                          color: colors.textSecondary,
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(width: 4),

            // Desktop Esc Key Hint
            if (isDesktop) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary.withValues(alpha: 0.8),
                  borderRadius: AppRadius.radiusMicro,
                  border: Border.all(
                    color: colors.surfaceBorder.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Esc',
                  style: typography.caption.regular.copyWith(
                    color: colors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],

            // Close Modal Button
            PlatformHoverBuilder(
              builder: (context, isHovered, child) {
                return IconButton(
                  iconSize: 20,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: 'Close Voice Dialogue',
                  icon: Icon(
                    Icons.close_rounded,
                    color: isHovered ? colors.primary : colors.textPrimary,
                  ),
                  onPressed: _closeModal,
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPortraitWorkspace(
    BuildContext context, {
    required Color stateColor,
    required bool isCompact,
    required bool isDesktop,
  }) {
    final hasResponse = _latestResponse.isNotEmpty;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!hasResponse) const Spacer(),

        // Siri / Gemini Glowing Acoustic Sound Ribbon
        GestureDetector(
          onTap: _onInteractionTap,
          behavior: HitTestBehavior.opaque,
          child: RepaintBoundary(
            child: _SoundRibbonWidget(
              stateColor: stateColor,
              state: _state,
              soundLevelNotifier: _soundLevelNotifier,
              animation: _ribbonAnimationController,
              height: isCompact ? 96 : (isDesktop ? 130 : 110),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Status Headline
        _buildStatusHeadline(context),

        const SizedBox(height: 8),

        // User Live Transcription Pill / Card
        if (_liveTranscript.isNotEmpty) ...[
          _buildLiveTranscriptCard(context),
          const SizedBox(height: 8),
        ],

        // Syllabot AI Response Viewer
        if (hasResponse) ...[
          Flexible(
            flex: 3,
            child: _buildResponseViewer(context, isDesktop: isDesktop),
          ),
        ],

        if (!hasResponse) const Spacer(),
      ],
    );
  }

  Widget _buildLandscapeWorkspace(
    BuildContext context, {
    required Color stateColor,
  }) {
    return Row(
      children: [
        // Left Column: Sound Ribbon & Status
        SizedBox(
          width: 240,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _onInteractionTap,
                behavior: HitTestBehavior.opaque,
                child: RepaintBoundary(
                  child: _SoundRibbonWidget(
                    stateColor: stateColor,
                    state: _state,
                    soundLevelNotifier: _soundLevelNotifier,
                    animation: _ribbonAnimationController,
                    height: 84,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildStatusHeadline(context, isCompact: true),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Right Column: Transcripts & Response
        Expanded(
          child: Column(
            children: [
              if (_liveTranscript.isNotEmpty) ...[
                _buildLiveTranscriptCard(context),
                const SizedBox(height: 6),
              ],
              Expanded(
                child: _latestResponse.isNotEmpty
                    ? _buildResponseViewer(context, isDesktop: false)
                    : Center(
                        child: Text(
                          'Syllabot voice assistant is ready.',
                          style: context.typography.caption.regular.copyWith(
                            color: context.colors.textMuted,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusHeadline(BuildContext context, {bool isCompact = false}) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isListening = _state == DialogueState.listening;
    final isThinking = _state == DialogueState.thinking;
    final isSpeaking = _state == DialogueState.speaking;
    final hasSpeech = _liveTranscript.trim().isNotEmpty;

    final headline = isListening
        ? (hasSpeech
              ? l10n.voiceDialogueListening
              : l10n.voiceDialogueListening)
        : isThinking
        ? '${l10n.voiceDialogueThinking} & analyzing...'
        : isSpeaking
        ? l10n.voiceDialogueSpeaking
        : l10n.voiceDialogueTapToSpeak;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isListening) ...[
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
        Text(
          headline,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (isCompact ? typography.title3.bold : typography.title2.bold)
              .copyWith(
                color: colors.textPrimary,
                fontSize: isCompact ? 16 : 18,
              ),
        ),
      ],
    );
  }

  Widget _buildLiveTranscriptCard(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShrinkableButton(
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            setState(() {
              _isTranscriptExpanded = !_isTranscriptExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: AppRadius.radiusBadge,
              border: Border.all(
                color: colors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.subtitles_rounded,
                  size: 13,
                  color: colors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  _isTranscriptExpanded
                      ? 'Hide Speech-to-Text 📝'
                      : 'Show Speech-to-Text (STT) 📝',
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isTranscriptExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ),
        if (_isTranscriptExpanded) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: AppRadius.radiusCard,
              border: Border.all(
                color: _state == DialogueState.listening
                    ? colors.primary.withValues(alpha: 0.5)
                    : colors.surfaceBorder.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              '"$_liveTranscript"',
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: typography.body.medium.copyWith(
                color: colors.textPrimary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResponseViewer(BuildContext context, {required bool isDesktop}) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isDesktop ? 620 : 540,
      ),
      child: ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.05, 0.95, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ChatBubbleWidget(
            message: ChatMessageEntity(
              id: 'dialogue_response',
              sessionId: 'dialogue_session',
              text: _latestResponse,
              sender: MessageSender.syllabot,
              timestamp: DateTime.now(),
            ),
            ttsHandler: widget.ttsHandler,
            showSpeakButton: false,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionDock(
    BuildContext context, {
    required Color stateColor,
    required bool isDesktop,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isListening = _state == DialogueState.listening;
    final isSpeaking = _state == DialogueState.speaking;
    final hasSpeech = _liveTranscript.trim().isNotEmpty;

    final buttonLabel = isListening
        ? (hasSpeech
              ? l10n.voiceDialogueDoneSpeaking
              : l10n.voiceDialogueListening)
        : isSpeaking
        ? l10n.voiceDialogueTapToSpeak
        : l10n.voiceDialogueTapToSpeak;

    final buttonIcon = isListening
        ? (hasSpeech ? Icons.arrow_upward_rounded : Icons.mic_rounded)
        : Icons.mic_rounded;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 480 : double.infinity,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceSecondary.withValues(
              alpha: isDark ? 0.9 : 0.8,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: colors.surfaceBorder.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 1. Mute Output Toggle Button
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: _toggleMute,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isMuted
                          ? colors.error.withValues(alpha: 0.15)
                          : colors.surfacePrimary,
                      border: Border.all(
                        color: _isMuted
                            ? colors.error.withValues(alpha: 0.4)
                            : colors.surfaceBorder.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(
                      _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: _isMuted ? colors.error : colors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // 2. Primary Hero Interaction Button
              Expanded(
                child: ShrinkableButton(
                  onTap: _onInteractionTap,
                  child: Material(
                    color: stateColor,
                    borderRadius: BorderRadius.circular(24),
                    elevation: 2,
                    shadowColor: stateColor.withValues(alpha: 0.35),
                    child: InkWell(
                      onTap: _onInteractionTap,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              buttonIcon,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                buttonLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.body.bold.copyWith(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // 3. End Session Button
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: _closeModal,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surfacePrimary,
                      border: Border.all(
                        color: colors.surfaceBorder.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(
                      Icons.close,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Siri / Gemini fluid multi-color acoustic sound ribbon visualizer.
class _SoundRibbonWidget extends StatelessWidget {
  const _SoundRibbonWidget({
    required this.stateColor,
    required this.state,
    required this.soundLevelNotifier,
    required this.animation,
    required this.height,
  });

  final Color stateColor;
  final DialogueState state;
  final ValueNotifier<double> soundLevelNotifier;
  final Animation<double> animation;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return ValueListenableBuilder<double>(
          valueListenable: soundLevelNotifier,
          builder: (context, soundLevel, _) {
            return CustomPaint(
              size: Size(double.infinity, height),
              painter: _SoundRibbonPainter(
                stateColor: stateColor,
                state: state,
                soundLevel: soundLevel,
                animationValue: animation.value,
              ),
            );
          },
        );
      },
    );
  }
}

/// GPU-accelerated sinusoidal acoustic ribbon painter with Siri/Gemini harmonic layers.
class _SoundRibbonPainter extends CustomPainter {
  _SoundRibbonPainter({
    required this.stateColor,
    required this.state,
    required this.soundLevel,
    required this.animationValue,
  });

  final Color stateColor;
  final DialogueState state;
  final double soundLevel;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    // Amplitude scale based on dialogue state and decibels
    final isListening = state == DialogueState.listening;
    final isSpeaking = state == DialogueState.speaking;
    final isThinking = state == DialogueState.thinking;

    final baseAmp = isListening
        ? (8.0 + soundLevel * 36.0)
        : isSpeaking
        ? 24.0
        : isThinking
        ? 14.0
        : 6.0;

    // Siri / Gemini multi-harmonic wave definitions
    // Each wave has [frequencyMultiplier, phaseOffset, amplitudeMultiplier, strokeWidth, primaryColor, secondaryColor]
    final waveLayers = [
      // 1. Ambient Glow Underlayer (Wide soft blur)
      _RibbonLayer(
        freq: 1,
        phase: animationValue * 2 * math.pi,
        amp: baseAmp * 1.1,
        strokeWidth: 6,
        colors: [
          stateColor.withValues(alpha: 0),
          const Color(0xFF00E5FF).withValues(alpha: 0.35),
          const Color(0xFF7C4DFF).withValues(alpha: 0.4),
          const Color(0xFFFF4081).withValues(alpha: 0.35),
          stateColor.withValues(alpha: 0),
        ],
        blur: 10,
      ),
      // 2. Cyan / Turquoise Wave (Crisp lead harmonic)
      _RibbonLayer(
        freq: 1.4,
        phase: (animationValue * 2 * math.pi) + 0.8,
        amp: baseAmp * 0.95,
        strokeWidth: 3.2,
        colors: [
          stateColor.withValues(alpha: 0),
          const Color(0xFF00E5FF),
          const Color(0xFF18FFFF),
          const Color(0xFF00B0FF),
          stateColor.withValues(alpha: 0),
        ],
      ),
      // 3. Purple / Indigo Wave (Deep harmonic counterpoint)
      _RibbonLayer(
        freq: 1.8,
        phase: (animationValue * 2 * math.pi) - 1.2,
        amp: baseAmp * 0.75,
        strokeWidth: 2.8,
        colors: [
          stateColor.withValues(alpha: 0),
          const Color(0xFF7C4DFF),
          const Color(0xFF651FFF),
          const Color(0xFFB388FF),
          stateColor.withValues(alpha: 0),
        ],
      ),
      // 4. Rose / Amber Wave (Warm harmonic shimmer)
      _RibbonLayer(
        freq: 2.2,
        phase: (animationValue * 2 * math.pi) + 2.4,
        amp: baseAmp * 0.55,
        strokeWidth: 2.2,
        colors: [
          stateColor.withValues(alpha: 0),
          const Color(0xFFFF4081),
          const Color(0xFFFF80AB),
          const Color(0xFFFFAB40),
          stateColor.withValues(alpha: 0),
        ],
      ),
      // 5. White Hot Center Filament (Luminous core)
      _RibbonLayer(
        freq: 1.2,
        phase: (animationValue * 2 * math.pi) + 0.4,
        amp: baseAmp * 0.85,
        strokeWidth: 1.6,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.85),
          Colors.white,
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0),
        ],
      ),
    ];

    for (final layer in waveLayers) {
      final path = Path();
      const sampleStep = 4.0;
      var isFirst = true;

      for (var x = 0.0; x <= width; x += sampleStep) {
        final progress = (x / width).clamp(0, 1);
        // Hanning-style window tapering to zero smoothly at both ends
        final envelope = math.sin(progress * math.pi);
        final envelopePowered = math.pow(envelope, 1.3).toDouble();

        final waveOffset = math.sin(
          (progress * layer.freq * 2 * math.pi) + layer.phase,
        );
        final y = centerY + (waveOffset * layer.amp * envelopePowered);

        if (isFirst) {
          path.moveTo(x, y);
          isFirst = false;
        } else {
          path.lineTo(x, y);
        }
      }

      final shader = LinearGradient(
        colors: layer.colors,
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, centerY - baseAmp, width, baseAmp * 2));

      final paint = Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = layer.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (layer.blur != null) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, layer.blur!);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoundRibbonPainter oldDelegate) {
    return oldDelegate.soundLevel != soundLevel ||
        oldDelegate.state != state ||
        oldDelegate.stateColor != stateColor ||
        oldDelegate.animationValue != animationValue;
  }
}

class _RibbonLayer {
  const _RibbonLayer({
    required this.freq,
    required this.phase,
    required this.amp,
    required this.strokeWidth,
    required this.colors,
    this.blur,
  });

  final double freq;
  final double phase;
  final double amp;
  final double strokeWidth;
  final List<Color> colors;
  final double? blur;
}
