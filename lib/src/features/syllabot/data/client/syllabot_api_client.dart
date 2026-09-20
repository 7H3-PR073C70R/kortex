import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:retrofit/retrofit.dart';

part 'syllabot_api_client.g.dart';

@RestApi()
abstract class SyllabotApiClient {
  factory SyllabotApiClient(Dio dio, {String baseUrl}) = _SyllabotApiClient;

  @GET(AppApiEndpoint.syllabotSessions)
  Future<HttpResponse<dynamic>> getChatSessions(
    @Queries() Map<String, dynamic> query,
  );

  @POST(AppApiEndpoint.syllabotSessions)
  Future<HttpResponse<dynamic>> createChatSession(
    @Body() Map<String, dynamic> body, {
    @Header('Prefer') String prefer = 'return=representation',
  });

  @GET(AppApiEndpoint.syllabotMessages)
  Future<HttpResponse<dynamic>> getSessionMessages(
    @Queries() Map<String, dynamic> query,
  );

  @DELETE(AppApiEndpoint.syllabotSessions)
  Future<HttpResponse<dynamic>> deleteSession(
    @Queries() Map<String, dynamic> query,
  );
}

/// Helper extension for SSE streaming from Syllabot edge functions.
extension SyllabotStreamExtension on Dio {
  Stream<String> streamSyllabotResponse({
    required String prompt,
    required String sessionId,
    required SocraticMode socraticMode,
    required ExecutionEngineType engine,
    List<Map<String, String>> contextHistory = const [],
  }) async* {
    final response = await post<ResponseBody>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.syllabotStream}',
      data: {
        'prompt': prompt,
        'sessionId': sessionId,
        'socraticMode': socraticMode.nameString,
        'contextHistory': contextHistory,
      },
      options: Options(
        headers: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(minutes: 5),
      ),
    );

    final stream = response.data?.stream;
    if (stream == null) throw Exception('No stream in response');

    final buffer = StringBuffer();

    await for (final textChunk
        in stream.cast<List<int>>().transform(utf8.decoder)) {
      buffer.write(textChunk);

      final lines = buffer.toString().split('\n');
      buffer.clear();

      for (var i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.startsWith('data:')) {
          final jsonStr = line.substring(5).trim();
          try {
            final decoded = jsonDecode(jsonStr);
            if (decoded is Map<String, dynamic>) {
              if (decoded.containsKey('error')) {
                final rawMsg = decoded['message']?.toString() ??
                    decoded['error']?.toString() ??
                    'AI provider error';
                final cleanedMsg = _cleanErrorMessage(rawMsg);
                throw Exception(cleanedMsg);
              }
              if (decoded.containsKey('text')) {
                yield decoded['text'] as String;
              }
            }
          } on FormatException {
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
          }
        }
      }

      if (lines.isNotEmpty) {
        buffer.write(lines.last);
      }
    }

    final remaining = buffer.toString().trim();
    if (remaining.startsWith('data:')) {
      final jsonStr = remaining.substring(5).trim();
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic> && decoded.containsKey('error')) {
          final rawMsg = decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              'AI provider error';
          final cleanedMsg = _cleanErrorMessage(rawMsg);
          throw Exception(cleanedMsg);
        }
      } on FormatException catch (_) {}
    }
  }

  static String _cleanErrorMessage(String rawMessage) {
    try {
      final jsonStart = rawMessage.indexOf('{');
      if (jsonStart != -1) {
        final jsonPart = rawMessage.substring(jsonStart);
        final decoded = jsonDecode(jsonPart);
        if (decoded is Map && decoded['error'] is Map) {
          final nestedMsg = (decoded['error'] as Map)['message']?.toString();
          if (nestedMsg != null && nestedMsg.isNotEmpty) {
            final prefix = rawMessage.substring(0, jsonStart).trim();
            return prefix.isNotEmpty ? '$prefix: $nestedMsg' : nestedMsg;
          }
        }
      }
    } on Object catch (_) {}
    return rawMessage;
  }
}
