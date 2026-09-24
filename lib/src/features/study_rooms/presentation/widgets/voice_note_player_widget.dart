import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// An interactive audio player widget for voice notes in forum posts and replies.
class VoiceNotePlayerWidget extends StatefulWidget {
  const VoiceNotePlayerWidget({
    required this.audioUrl,
    this.durationSeconds,
    this.onDelete,
    this.compact = false,
    super.key,
  });

  final String audioUrl;
  final int? durationSeconds;
  final VoidCallback? onDelete;
  final bool compact;

  @override
  State<VoiceNotePlayerWidget> createState() => _VoiceNotePlayerWidgetState();
}

class _VoiceNotePlayerWidgetState extends State<VoiceNotePlayerWidget> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

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
    }

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) {
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
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    unawaited(_stateSub?.cancel());
    unawaited(_posSub?.cancel());
    unawaited(_durSub?.cancel());
    unawaited(_completeSub?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _togglePlay() async {
    unawaited(HapticFeedback.lightImpact());
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        Source source;
        if (widget.audioUrl.startsWith('http://') ||
            widget.audioUrl.startsWith('https://')) {
          source = UrlSource(widget.audioUrl);
        } else if (File(widget.audioUrl).existsSync()) {
          source = DeviceFileSource(widget.audioUrl);
        } else if (widget.audioUrl.startsWith('assets/') ||
            widget.audioUrl.startsWith('audio/')) {
          final path = widget.audioUrl.replaceFirst('assets/', '');
          source = AssetSource(path);
        } else {
          source = DeviceFileSource(widget.audioUrl);
        }
        await _player.play(source);
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final progress = (_totalDuration.inMilliseconds > 0)
        ? (_position.inMilliseconds / _totalDuration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return Container(
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
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mic_rounded,
                          size: 13,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Voice Note',
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _totalDuration.inSeconds > 0
                          ? '${_formatDuration(_position)} / ${_formatDuration(_totalDuration)}'
                          : _formatDuration(_position),
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: colors.primary.withAlpha(isDark ? 40 : 25),
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
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
    );
  }
}
