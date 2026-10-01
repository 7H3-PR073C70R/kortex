import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';

enum ForumMediaType {
  image,
  voice,
}

/// Secure server-side media upload service that uploads files to Cloudflare R2
/// via Supabase Edge Functions with zero client credentials leakage and client-side compression.
class MediaUploadService {
  MediaUploadService({Dio? dioClient}) : _dio = dioClient ?? locator<Dio>();

  final Dio _dio;

  /// Uploads a media file (Image or Voice Note) to Cloudflare R2
  /// via the secure `/upload-forum-media` server endpoint.
  Future<String> uploadMedia({
    required File file,
    required ForumMediaType mediaType,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (!file.existsSync()) {
      throw Exception('File does not exist: ${file.path}');
    }

    final originalFileName = file.path.split(Platform.pathSeparator).last;
    final extension = originalFileName.contains('.')
        ? originalFileName.split('.').last.toLowerCase()
        : (mediaType == ForumMediaType.image ? 'webp' : 'm4a');

    var mimeType = 'application/octet-stream';
    if (mediaType == ForumMediaType.image) {
      mimeType = extension == 'png'
          ? 'image/png'
          : (extension == 'jpg' || extension == 'jpeg'
              ? 'image/jpeg'
              : 'image/webp');
    } else {
      mimeType = extension == 'wav'
          ? 'audio/wav'
          : (extension == 'mp3' ? 'audio/mpeg' : 'audio/m4a');
    }

    final bytes = await file.readAsBytes();
    final userStorage = locator.isRegistered<UserStorageService>()
        ? locator<UserStorageService>()
        : null;
    final token = userStorage?.getToken();

    final reqHeaders = <String, dynamic>{
      'Content-Type': mimeType,
      'x-media-type': mediaType.name,
      'x-file-name': originalFileName,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final url = '${AppApiEndpoint.baseUri}${AppApiEndpoint.uploadForumMedia}';

    final response = await _dio.post<Map<String, dynamic>>(
      url,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: reqHeaders,
      ),
      onSendProgress: onProgress,
    );

    if (response.statusCode == 200 && response.data != null) {
      final resData = response.data!;
      final returnedUrl = resData['url'] as String? ?? resData['proxyUrl'] as String?;
      if (returnedUrl != null && returnedUrl.isNotEmpty) {
        return returnedUrl;
      }
    }

    throw Exception(
      'Failed to upload media: ${response.statusCode} ${response.statusMessage}',
    );
  }

  static final Map<String, String> _memoryCache = {};
  static final Map<String, Future<String?>> _inFlightTranscriptions = {};

  @visibleForTesting
  static void clearCacheForTesting() {
    _memoryCache.clear();
    _inFlightTranscriptions.clear();
  }

  static String _cacheKey(String audioUrl, {String? replyId, String? postId}) {
    final cleanUrl = audioUrl.trim();
    if (replyId != null && replyId.isNotEmpty) {
      return 'reply:$replyId';
    }
    if (postId != null && postId.isNotEmpty) {
      return 'post:$postId';
    }
    return 'url:$cleanUrl';
  }

  /// Synchronously looks up any cached transcript from memory or LocalStorageService.
  static String? getCachedTranscript({
    required String audioUrl,
    String? replyId,
    String? postId,
  }) {
    final cleanUrl = audioUrl.trim();
    if (cleanUrl.isNotEmpty && _memoryCache.containsKey('url:$cleanUrl')) {
      return _memoryCache['url:$cleanUrl'];
    }
    if (replyId != null &&
        replyId.isNotEmpty &&
        _memoryCache.containsKey('reply:$replyId')) {
      return _memoryCache['reply:$replyId'];
    }
    if (postId != null &&
        postId.isNotEmpty &&
        _memoryCache.containsKey('post:$postId')) {
      return _memoryCache['post:$postId'];
    }

    // Check persistent LocalStorageService if available
    try {
      if (locator.isRegistered<LocalStorageService>()) {
        final storage = locator<LocalStorageService>();
        if (cleanUrl.isNotEmpty) {
          final stored =
              storage.getPreference(key: 'vn_trans_${cleanUrl.hashCode}');
          if (stored != null && stored.trim().isNotEmpty) {
            _memoryCache['url:$cleanUrl'] = stored.trim();
            return stored.trim();
          }
        }
        if (replyId != null && replyId.isNotEmpty) {
          final stored = storage.getPreference(key: 'vn_reply_$replyId');
          if (stored != null && stored.trim().isNotEmpty) {
            _memoryCache['reply:$replyId'] = stored.trim();
            return stored.trim();
          }
        }
        if (postId != null && postId.isNotEmpty) {
          final stored = storage.getPreference(key: 'vn_post_$postId');
          if (stored != null && stored.trim().isNotEmpty) {
            _memoryCache['post:$postId'] = stored.trim();
            return stored.trim();
          }
        }
      }
    } on Object catch (_) {}

    return null;
  }

  /// Caches a transcript in memory and persists to LocalStorageService.
  static void cacheTranscript({
    required String audioUrl,
    required String transcript,
    String? replyId,
    String? postId,
  }) {
    final cleanText = transcript.trim();
    if (cleanText.isEmpty) return;

    final cleanUrl = audioUrl.trim();
    if (cleanUrl.isNotEmpty) {
      _memoryCache['url:$cleanUrl'] = cleanText;
    }
    if (replyId != null && replyId.isNotEmpty) {
      _memoryCache['reply:$replyId'] = cleanText;
    }
    if (postId != null && postId.isNotEmpty) {
      _memoryCache['post:$postId'] = cleanText;
    }

    // Persist in background
    try {
      if (locator.isRegistered<LocalStorageService>()) {
        final storage = locator<LocalStorageService>();
        if (cleanUrl.isNotEmpty) {
          unawaited(storage.savePreference(
            key: 'vn_trans_${cleanUrl.hashCode}',
            data: cleanText,
          ));
        }
        if (replyId != null && replyId.isNotEmpty) {
          unawaited(storage.savePreference(
            key: 'vn_reply_$replyId',
            data: cleanText,
          ));
        }
        if (postId != null && postId.isNotEmpty) {
          unawaited(storage.savePreference(
            key: 'vn_post_$postId',
            data: cleanText,
          ));
        }
      }
    } on Object catch (_) {}
  }

  /// Transcribes a recorded voice note via the Supabase Edge Function (Groq Whisper),
  /// with aggressive memory + persistent caching and in-flight request deduplication.
  ///
  /// Returns the transcribed text string if successful, or null on error.
  Future<String?> transcribeVoiceNote({
    required String audioUrl,
    String? replyId,
    String? postId,
  }) async {
    final cleanUrl = audioUrl.trim();
    if (cleanUrl.isEmpty) return null;

    // 1. Check existing cache
    final cached = getCachedTranscript(
      audioUrl: cleanUrl,
      replyId: replyId,
      postId: postId,
    );
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // 2. Check if already in-flight (deduplication)
    final inFlightKey = _cacheKey(cleanUrl, replyId: replyId, postId: postId);
    if (_inFlightTranscriptions.containsKey(inFlightKey)) {
      return await _inFlightTranscriptions[inFlightKey];
    }

    final completer = Completer<String?>();
    _inFlightTranscriptions[inFlightKey] = completer.future;

    try {
      final endpoint =
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.transcribeVoiceNote}';
      if (endpoint.isEmpty || endpoint == AppApiEndpoint.transcribeVoiceNote) {
        completer.complete(null);
        return null;
      }
      final userStorage = locator.isRegistered<UserStorageService>()
          ? locator<UserStorageService>()
          : null;
      final token = userStorage?.getToken();
      final effectiveToken = (token != null && token.isNotEmpty)
          ? token
          : AppEnv.apiKey;

      final response = await _dio.post<dynamic>(
        endpoint,
        data: {
          'audio_url': cleanUrl,
          if (replyId != null && replyId.isNotEmpty) 'reply_id': replyId,
          if (postId != null && postId.isNotEmpty) 'post_id': postId,
        },
        options: Options(
          headers: {
            if (AppEnv.apiKey.isNotEmpty) 'apikey': AppEnv.apiKey,
            if (effectiveToken.isNotEmpty)
              'Authorization': 'Bearer $effectiveToken',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 40),
          receiveTimeout: const Duration(seconds: 40),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map) {
          final transcript = data['transcript'] as String?;
          if (transcript != null && transcript.trim().isNotEmpty) {
            final cleanText = transcript.trim();
            cacheTranscript(
              audioUrl: cleanUrl,
              replyId: replyId,
              postId: postId,
              transcript: cleanText,
            );
            completer.complete(cleanText);
            return cleanText;
          }
        }
      }
      completer.complete(null);
      return null;
    } on Object catch (e) {
      debugPrint('MediaUploadService: transcribeVoiceNote error: $e');
      completer.complete(null);
      return null;
    } finally {
      unawaited(_inFlightTranscriptions.remove(inFlightKey));
    }
  }

  /// Triggers server-side Groq Whisper transcription (fire-and-forget wrapper).
  Future<void> triggerVoiceNoteTranscription({
    required String audioUrl,
    String? replyId,
    String? postId,
  }) async {
    await transcribeVoiceNote(
      audioUrl: audioUrl,
      replyId: replyId,
      postId: postId,
    );
  }
}
