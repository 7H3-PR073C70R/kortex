import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
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

  /// Transcribes a recorded voice note via the Supabase Edge Function (Groq Whisper).
  ///
  /// Returns the transcribed text string if successful, or null on error.
  Future<String?> transcribeVoiceNote({
    required String audioUrl,
    String? replyId,
    String? postId,
  }) async {
    try {
      final endpoint =
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.transcribeVoiceNote}';
      if (endpoint.isEmpty || endpoint == AppApiEndpoint.transcribeVoiceNote) {
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
          'audio_url': audioUrl,
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
            return transcript.trim();
          }
        }
      }
      return null;
    } on Object catch (e) {
      debugPrint('MediaUploadService: transcribeVoiceNote error: $e');
      return null;
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
