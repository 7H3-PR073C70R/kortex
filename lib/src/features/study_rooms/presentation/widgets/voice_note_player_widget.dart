import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/services/media_upload_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player/voice_note_player_card.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player/voice_note_transcript_panel.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player/voice_note_transcript_toggle.dart';

// Re-export sub-widgets for seamless modular access
export 'voice_note_player/voice_note_player_card.dart';
export 'voice_note_player/voice_note_transcript_panel.dart';
export 'voice_note_player/voice_note_transcript_toggle.dart';

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
    this.mediaUploadService,
    this.audioPlayer,
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
  final MediaUploadService? mediaUploadService;
  final AudioPlayer? audioPlayer;
  final bool compact;
  final bool showTranscript;

  @override
  State<VoiceNotePlayerWidget> createState() => _VoiceNotePlayerWidgetState();
}

class _VoiceNotePlayerWidgetState extends State<VoiceNotePlayerWidget> {
  AudioPlayer? _player;
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

  AudioPlayer _ensurePlayerInitialized() {
    if (_player != null) return _player!;
    final p = widget.audioPlayer ?? AudioPlayer();
    _stateSub = p.onPlayerStateChanged.listen((state) {
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

    _posSub = p.onPositionChanged.listen((pos) {
      if (mounted && pos.inMilliseconds > 0) {
        setState(() {
          _position = pos;
        });
      }
    });

    _durSub = p.onDurationChanged.listen((dur) {
      if (mounted && dur.inSeconds > 0) {
        setState(() {
          _totalDuration = dur;
        });
      }
    });

    _completeSub = p.onPlayerComplete.listen((_) {
      if (mounted) {
        _stopFallbackTimer();
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    _player = p;
    return p;
  }

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

    if (widget.durationSeconds != null && widget.durationSeconds! > 0) {
      _totalDuration = Duration(seconds: widget.durationSeconds!);
    } else {
      _totalDuration = const Duration(seconds: 5);
    }
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
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _togglePlay() async {
    unawaited(HapticFeedback.lightImpact());

    if (_isPlaying) {
      _stopFallbackTimer();
      try {
        await _player?.pause();
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
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
      if (rawUrl.startsWith('http://') ||
          rawUrl.startsWith('https://') ||
          rawUrl.startsWith('blob:')) {
        source = UrlSource(rawUrl);
      } else if (!kIsWeb && cleanPath.isNotEmpty && File(cleanPath).existsSync()) {
        source = DeviceFileSource(cleanPath);
      } else if (rawUrl.startsWith('assets/') || rawUrl.startsWith('audio/')) {
        final path = rawUrl.startsWith('assets/')
            ? rawUrl.replaceFirst('assets/', '')
            : rawUrl;
        source = AssetSource(path);
      } else if (kIsWeb && cleanPath.isNotEmpty) {
        source = UrlSource(cleanPath);
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

      final player = _ensurePlayerInitialized();
      await player.setPlaybackRate(_playbackRate);
      await player.play(source);

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
    final player = _player;
    if (player != null) {
      unawaited(player.setPlaybackRate(_playbackRate));
    }
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
        final uploadService = widget.mediaUploadService ??
            (locator.isRegistered<MediaUploadService>()
                ? locator<MediaUploadService>()
                : MediaUploadService());
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
    final hasTranscript = _currentTranscript != null &&
        _currentTranscript!.trim().isNotEmpty;
    final effectiveTranscript =
        hasTranscript ? _currentTranscript!.trim() : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VoiceNotePlayerCard(
          isPlaying: _isPlaying,
          position: _position,
          totalDuration: _totalDuration,
          playbackRate: _playbackRate,
          onTogglePlay: _togglePlay,
          onCyclePlaybackRate: _cyclePlaybackRate,
          onDelete: widget.onDelete,
          compact: widget.compact,
        ),
        if (widget.showTranscript) ...[
          const SizedBox(height: 8),
          VoiceNoteTranscriptToggle(
            isTranscribing: _isTranscribing,
            isTranscriptExpanded: _isTranscriptExpanded,
            effectiveTranscript: effectiveTranscript,
            onToggleTranscript: _toggleTranscript,
          ),
          if (_isTranscriptExpanded) ...[
            const SizedBox(height: 6),
            VoiceNoteTranscriptPanel(
              isTranscribing: _isTranscribing,
              transcriptionError: _transcriptionError,
              currentTranscript: _currentTranscript,
              effectiveTranscript: effectiveTranscript,
              onRetry: () => unawaited(_fetchTranscription()),
              onCopyTranscript: _copyTranscript,
            ),
          ],
        ],
      ],
    );
  }
}
