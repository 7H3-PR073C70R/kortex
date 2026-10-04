import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/media_upload_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// An interactive audio player widget for voice notes in forum posts and replies
/// with toggleable Speech-to-Text transcript display.
class VoiceNotePlayerWidget extends StatefulWidget {
  const VoiceNotePlayerWidget({
    required this.audioUrl,
    this.replyId,
    this.postId,
    this.durationSeconds,
    this.transcript,
    this.onTranscriptLoaded,
    this.onTranscribe,
    this.onDelete,
    this.compact = false,
    this.showTranscript = true,
    super.key,
  });

  final String audioUrl;
  final String? replyId;
  final String? postId;
  final int? durationSeconds;
  final String? transcript;
  final ValueChanged<String>? onTranscriptLoaded;
  final Future<String?> Function({
    required String audioUrl,
    String? replyId,
    String? postId,
  })? onTranscribe;
  final VoidCallback? onDelete;
  final bool compact;
  final bool showTranscript;

  @override
  State<VoiceNotePlayerWidget> createState() => _VoiceNotePlayerWidgetState();
}

class _VoiceNotePlayerWidgetState extends State<VoiceNotePlayerWidget> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _isTranscriptExpanded = false;
  String? _currentTranscript;
  bool _isTranscribing = false;
  String? _transcriptionError;
  double _playbackRate = 1;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _fallbackTimer;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    final provided = (widget.transcript != null &&
            widget.transcript!.trim().isNotEmpty)
        ? widget.transcript!.trim()
        : null;

    if (provided != null) {
      _currentTranscript = provided;
      MediaUploadService.cacheTranscript(
        audioUrl: widget.audioUrl,
        replyId: widget.replyId,
        postId: widget.postId,
        transcript: provided,
      );
    } else {
      _currentTranscript = MediaUploadService.getCachedTranscript(
        audioUrl: widget.audioUrl,
        replyId: widget.replyId,
        postId: widget.postId,
      );
    }

    _player = AudioPlayer();
    if (widget.durationSeconds != null && widget.durationSeconds! > 0) {
      _totalDuration = Duration(seconds: widget.durationSeconds!);
    } else {
      _totalDuration = const Duration(seconds: 5);
    }

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
        if (state == PlayerState.playing) {
          _startFallbackTimer();
        } else {
          _stopFallbackTimer();
        }
      }
    });

    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted && pos.inMilliseconds > 0) {
        setState(() {
          _position = pos;
        });
      }
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (mounted && dur.inSeconds > 0) {
        setState(() {
          _totalDuration = dur;
        });
      }
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        _stopFallbackTimer();
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void didUpdateWidget(VoiceNotePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transcript != oldWidget.transcript) {
      if (widget.transcript != null && widget.transcript!.trim().isNotEmpty) {
        final text = widget.transcript!.trim();
        setState(() {
          _currentTranscript = text;
          _transcriptionError = null;
        });
        MediaUploadService.cacheTranscript(
          audioUrl: widget.audioUrl,
          replyId: widget.replyId,
          postId: widget.postId,
          transcript: text,
        );
      }
    }
  }

  @override
  void dispose() {
    _stopFallbackTimer();
    unawaited(_stateSub?.cancel());
    unawaited(_posSub?.cancel());
    unawaited(_durSub?.cancel());
    unawaited(_completeSub?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _togglePlay() async {
    unawaited(HapticFeedback.lightImpact());

    if (_isPlaying) {
      _stopFallbackTimer();
      try {
        await _player.pause();
      } on Object catch (_) {}
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
      return;
    }

    try {
      final rawUrl = widget.audioUrl.trim();
      final cleanPath = rawUrl.startsWith('file://')
          ? rawUrl.replaceFirst('file://', '')
          : rawUrl;

      Source? source;
      if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
        source = UrlSource(rawUrl);
      } else if (cleanPath.isNotEmpty && File(cleanPath).existsSync()) {
        source = DeviceFileSource(cleanPath);
      } else if (rawUrl.startsWith('assets/') || rawUrl.startsWith('audio/')) {
        final path = rawUrl.startsWith('assets/')
            ? rawUrl.replaceFirst('assets/', '')
            : rawUrl;
        source = AssetSource(path);
      } else if (cleanPath.isNotEmpty) {
        source = DeviceFileSource(cleanPath);
      }

      if (source == null) {
        if (mounted) {
          context.showSnackBar(
            message: 'Voice note file not found',
            type: SnackBarType.error,
          );
        }
        return;
      }

      await _player.setPlaybackRate(_playbackRate);
      await _player.play(source);

      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
        _startFallbackTimer();
      }
    } on Object catch (e) {
      debugPrint('VoiceNotePlayerWidget: playback error: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
        _stopFallbackTimer();
        context.showSnackBar(
          message: 'Unable to play voice note',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isPlaying) {
        timer.cancel();
        return;
      }
      setState(() {
        final addMs = (100 * _playbackRate).round();
        final nextMs = _position.inMilliseconds + addMs;
        final maxMs = _totalDuration.inMilliseconds > 0
            ? _totalDuration.inMilliseconds
            : 5000;

        if (nextMs >= maxMs) {
          _position = Duration.zero;
          _isPlaying = false;
          timer.cancel();
        } else {
          _position = Duration(milliseconds: nextMs);
        }
      });
    });
  }

  void _stopFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _cyclePlaybackRate() {
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      if (_playbackRate == 1.0) {
        _playbackRate = 1.25;
      } else if (_playbackRate == 1.25) {
        _playbackRate = 1.5;
      } else if (_playbackRate == 1.5) {
        _playbackRate = 2.0;
      } else {
        _playbackRate = 1.0;
      }
    });
    unawaited(_player.setPlaybackRate(_playbackRate));
  }

  void _toggleTranscript() {
    unawaited(HapticFeedback.lightImpact());
    final willExpand = !_isTranscriptExpanded;

    if (willExpand) {
      if (_currentTranscript == null || _currentTranscript!.trim().isEmpty) {
        final cached = MediaUploadService.getCachedTranscript(
          audioUrl: widget.audioUrl,
          replyId: widget.replyId,
          postId: widget.postId,
        );
        if (cached != null && cached.isNotEmpty) {
          setState(() {
            _isTranscriptExpanded = true;
            _currentTranscript = cached;
            _isTranscribing = false;
            _transcriptionError = null;
          });
          widget.onTranscriptLoaded?.call(cached);
          return;
        }

        // Expand directly into transcribing state so user never sees empty state flash
        setState(() {
          _isTranscriptExpanded = true;
          _isTranscribing = true;
          _transcriptionError = null;
        });
        unawaited(_fetchTranscription());
        return;
      }
    }

    setState(() {
      _isTranscriptExpanded = willExpand;
    });
  }

  Future<void> _fetchTranscription() async {
    if (_currentTranscript != null && _currentTranscript!.trim().isNotEmpty) {
      if (mounted && _isTranscribing) {
        setState(() {
          _isTranscribing = false;
        });
      }
      return;
    }

    final audioUrl = widget.audioUrl.trim();
    if (audioUrl.isEmpty) {
      setState(() {
        _isTranscribing = false;
        _transcriptionError = 'Audio URL is empty.';
      });
      return;
    }

    if (!_isTranscribing) {
      setState(() {
        _isTranscribing = true;
        _transcriptionError = null;
      });
    }

    try {
      String? result;
      if (widget.onTranscribe != null) {
        result = await widget.onTranscribe!(
          audioUrl: audioUrl,
          replyId: widget.replyId,
          postId: widget.postId,
        );
      } else {
        final uploadService = locator.isRegistered<MediaUploadService>()
            ? locator<MediaUploadService>()
            : MediaUploadService();
        result = await uploadService.transcribeVoiceNote(
          audioUrl: audioUrl,
          replyId: widget.replyId,
          postId: widget.postId,
        );
      }

      if (!mounted) return;

      if (result != null && result.trim().isNotEmpty) {
        final cleanText = result.trim();
        MediaUploadService.cacheTranscript(
          audioUrl: audioUrl,
          replyId: widget.replyId,
          postId: widget.postId,
          transcript: cleanText,
        );
        setState(() {
          _currentTranscript = cleanText;
          _isTranscribing = false;
          _transcriptionError = null;
        });
        widget.onTranscriptLoaded?.call(cleanText);
      } else {
        setState(() {
          _isTranscribing = false;
          _transcriptionError =
              'Could not generate transcript. Tap to retry.';
        });
      }
    } on Object catch (e) {
      debugPrint('VoiceNotePlayerWidget: transcription failed: $e');
      if (mounted) {
        setState(() {
          _isTranscribing = false;
          _transcriptionError = 'Transcription failed. Tap to retry.';
        });
      }
    }
  }

  void _copyTranscript(BuildContext context, String text) {
    if (text.trim().isEmpty) return;
    unawaited(HapticFeedback.lightImpact());
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    context.showSnackBar(
      message: 'Transcript copied to clipboard 📋',
      type: SnackBarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final hasTranscript = _currentTranscript != null &&
        _currentTranscript!.trim().isNotEmpty;
    final effectiveTranscript =
        hasTranscript ? _currentTranscript!.trim() : null;

    final progress = (_totalDuration.inMilliseconds > 0)
        ? (_position.inMilliseconds / _totalDuration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 10 : 14,
            vertical: widget.compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: colors.primary.withAlpha(isDark ? 28 : 14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 55 : 30),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play / Pause Circle Button
              ShrinkableButton(
                onTap: _togglePlay,
                child: Container(
                  width: widget.compact ? 34 : 40,
                  height: widget.compact ? 34 : 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withAlpha(30),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: colors.white,
                    size: widget.compact ? 20 : 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Progress Bar / Waveform & Timestamps
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.mic_rounded,
                                size: 13,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Voice Note',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 11.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _totalDuration.inSeconds > 0
                                  ? '${_formatDuration(_position)} / ${_formatDuration(_totalDuration)}'
                                  : _formatDuration(_position),
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ShrinkableButton(
                              onTap: _cyclePlaybackRate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(
                                    isDark ? 50 : 25,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_playbackRate.toStringAsFixed(_playbackRate % 1 == 0 ? 0 : 2)}x',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: colors.primary.withAlpha(
                          isDark ? 40 : 25,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Delete button (if in editing/preview mode)
              if (widget.onDelete != null) ...[
                const SizedBox(width: 10),
                ShrinkableButton(
                  onTap: widget.onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.error.withAlpha(isDark ? 35 : 20),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: colors.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Expandable Speech-to-Text Transcript Section — always visible when showTranscript is true
        if (widget.showTranscript) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ShrinkableButton(
              onTap: _toggleTranscript,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: (effectiveTranscript != null || _isTranscribing)
                      ? colors.primary.withAlpha(isDark ? 35 : 20)
                      : colors.surfaceSecondary.withAlpha(isDark ? 120 : 80),
                  borderRadius: AppRadius.radiusBadge,
                  border: Border.all(
                    color: (effectiveTranscript != null || _isTranscribing)
                        ? colors.primary.withAlpha(isDark ? 70 : 40)
                        : colors.surfaceBorder.withAlpha(isDark ? 60 : 35),
                    width: 0.9,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isTranscribing) ...[
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ] else ...[
                      Icon(
                        Icons.subtitles_rounded,
                        size: 13,
                        color: effectiveTranscript != null
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      _isTranscribing
                          ? 'Transcribing with AI... 🎙️'
                          : _isTranscriptExpanded
                              ? 'Hide Transcript'
                              : 'Show Speech-to-Text 📝',
                      style: typography.caption.bold.copyWith(
                        color: (effectiveTranscript != null || _isTranscribing)
                            ? colors.primary
                            : colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isTranscriptExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: (effectiveTranscript != null || _isTranscribing)
                          ? colors.primary
                          : colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded panel — shows transcript text OR an empty state
          if (_isTranscriptExpanded) ...[
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: AppMotion.standard,
              curve: AppMotion.easeOutCubic,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(200)
                    : colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: effectiveTranscript != null
                      ? colors.primary.withAlpha(isDark ? 55 : 35)
                      : _transcriptionError != null
                          ? colors.error.withAlpha(isDark ? 80 : 50)
                          : colors.surfaceBorder.withAlpha(isDark ? 50 : 30),
                ),
              ),
              child: _buildTranscriptContent(context),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildTranscriptContent(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    if (_isTranscribing) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Transcribing voice note with AI Whisper...',
              style: typography.caption.medium.copyWith(
                color: colors.primary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }

    if (_transcriptionError != null) {
      return ShrinkableButton(
        onTap: () => unawaited(_fetchTranscription()),
        child: Row(
          children: [
            Icon(
              Icons.refresh_rounded,
              size: 16,
              color: colors.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _transcriptionError!,
                style: typography.caption.medium.copyWith(
                  color: colors.error,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.error.withAlpha(isDark ? 40 : 20),
                borderRadius: AppRadius.radiusMicro,
              ),
              child: Text(
                'Retry',
                style: typography.caption.bold.copyWith(
                  color: colors.error,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_currentTranscript != null && _currentTranscript!.trim().isNotEmpty) {
      final text = _currentTranscript!.trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: 14,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SPEECH-TO-TEXT TRANSCRIPT',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              ShrinkableButton(
                onTap: () => _copyTranscript(context, text),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 40 : 20),
                    borderRadius: AppRadius.radiusMicro,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        size: 11,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: typography.body.regular.copyWith(
                  color: colors.textPrimary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ShrinkableButton(
      onTap: () => unawaited(_fetchTranscription()),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No transcript available. Tap to transcribe with AI 🎙️',
              style: typography.caption.medium.copyWith(
                color: colors.primary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
