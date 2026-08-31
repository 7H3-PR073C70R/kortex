import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';

/// Handles SSE streaming from Supabase Edge Function and REST CRUD for
/// chat sessions.
class SupabaseSyllabotClient {
  SupabaseSyllabotClient(this._dio);

  final Dio _dio;

  /// Streams tokens from the `syllabot-stream` Edge Function via SSE.
  Stream<String> streamResponse({
    required String prompt,
    required String sessionId,
    required SocraticMode socraticMode,
    required ExecutionEngineType engine,
    List<Map<String, String>> contextHistory = const [],
    String? authToken,
  }) async* {
    final controller = StreamController<String>();
    CancelToken? cancelToken;

    try {
      cancelToken = CancelToken();

      final headers = {
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'apikey': AppEnv.supabaseAnonKey,
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

      final response = await _dio.post<ResponseBody>(
        '${AppApiEndpoint.baseUri}${AppApiEndpoint.syllabotStream}',
        data: {
          'prompt': prompt,
          'sessionId': sessionId,
          'socraticMode': socraticMode.nameString,
          'contextHistory': contextHistory,
        },
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 5),
        ),
        cancelToken: cancelToken,
      );

      final stream = response.data?.stream;
      if (stream == null) return;

      final buffer = StringBuffer();

      await for (final chunk in stream) {
        final raw = String.fromCharCodes(chunk);
        buffer.write(raw);

        final lines = buffer.toString().split('\n');
        buffer.clear();

        // Keep incomplete last line in buffer
        for (var i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.startsWith('data:')) {
            final jsonStr = line.substring(5).trim();
            try {
              // Parse SSE event data
              if (jsonStr.contains('"text"')) {
                final textMatch = RegExp(
                  r'"text"\s*:\s*"((?:[^"\\]|\\.)*)"',
                ).firstMatch(jsonStr);
                if (textMatch != null) {
                  final text = textMatch
                      .group(1)!
                      .replaceAll(r'\n', '\n')
                      .replaceAll(r'\"', '"')
                      .replaceAll(r'\\', r'\');
                  yield text;
                }
              }
            } on Object {
              // Skip malformed SSE lines
            }
          }
        }

        // Put incomplete line back into buffer
        if (lines.isNotEmpty) {
          buffer.write(lines.last);
        }
      }
    } on Object catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    } finally {
      await controller.close();
    }
  }

  /// Fetches all chat sessions for the authenticated user.
  Future<List<Map<String, dynamic>>> getChatSessions(String authToken) async {
    final response = await _dio.get<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.syllabotSessions}',
      queryParameters: {'select': '*', 'order': 'updated_at.desc'},
      options: Options(
        headers: {
          'apikey': AppEnv.supabaseAnonKey,
          'Authorization': 'Bearer $authToken',
        },
      ),
    );
    return (response.data ?? []).cast<Map<String, dynamic>>();
  }

  /// Creates a new chat session.
  Future<Map<String, dynamic>> createChatSession({
    required String title,
    required String socraticMode,
    required String authToken,
  }) async {
    final response = await _dio.post<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.syllabotSessions}',
      data: {'title': title, 'socratic_mode': socraticMode},
      options: Options(
        headers: {
          'apikey': AppEnv.supabaseAnonKey,
          'Authorization': 'Bearer $authToken',
          'Prefer': 'return=representation',
        },
      ),
    );
    final data = response.data;
    if (data == null || data.isEmpty) throw Exception('No session returned');
    return data.first as Map<String, dynamic>;
  }

  /// Fetches messages for a session.
  Future<List<Map<String, dynamic>>> getSessionMessages({
    required String sessionId,
    required String authToken,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.syllabotMessages}',
      queryParameters: {
        'select': '*',
        'session_id': 'eq.$sessionId',
        'order': 'created_at.asc',
      },
      options: Options(
        headers: {
          'apikey': AppEnv.supabaseAnonKey,
          'Authorization': 'Bearer $authToken',
        },
      ),
    );
    return (response.data ?? []).cast<Map<String, dynamic>>();
  }

  /// Deletes a chat session (cascade will remove messages).
  Future<void> deleteSession({
    required String sessionId,
    required String authToken,
  }) async {
    await _dio.delete<dynamic>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.syllabotSessions}',
      queryParameters: {'id': 'eq.$sessionId'},
      options: Options(
        headers: {
          'apikey': AppEnv.supabaseAnonKey,
          'Authorization': 'Bearer $authToken',
        },
      ),
    );
  }
}
