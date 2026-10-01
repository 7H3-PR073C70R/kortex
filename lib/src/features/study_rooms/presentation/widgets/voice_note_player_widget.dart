import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// An interactive audio player widget for voice notes in forum posts and replies
/// with toggleable Speech-to-Text transcript display.
class VoiceNotePlayerWidget extends StatefulWidget {
  const VoiceNotePlayerWidget({
    required this.audioUrl,
    this.durationSeconds,
    this.transcript,
    this.onDelete,
    this.compact = false,
    this.showTranscript = true,
    super.key,
  });

  final String audioUrl;
  final int? durationSeconds;
  final String? transcript;
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
    setState(() {
      _isTranscriptExpanded = !_isTranscriptExpanded;
    });
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

    final hasProvidedTranscript =
        widget.transcript != null && widget.transcript!.trim().isNotEmpty;
    final effectiveTranscript =
        hasProvidedTranscript ? widget.transcript!.trim() : null;

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

        // Expandable Speech-to-Text Transcript Section
        if (widget.showTranscript && effectiveTranscript != null) ...[
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
                  color: colors.primary.withAlpha(isDark ? 35 : 20),
                  borderRadius: AppRadius.radiusBadge,
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 70 : 40),
                    width: 0.9,
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
                      size: 15,
                      color: colors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded Speech-to-Text Transcript Box
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
                  color: colors.primary.withAlpha(isDark ? 55 : 35),
                ),
              ),
              child: Column(
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
                        onTap: () => _copyTranscript(context, effectiveTranscript),
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
                    constraints: const BoxConstraints(
                      maxHeight: 180,
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        effectiveTranscript,
                        style: typography.body.regular.copyWith(
                          color: colors.textPrimary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}
