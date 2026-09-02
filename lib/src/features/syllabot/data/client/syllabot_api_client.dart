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

    await for (final chunk in stream) {
      final raw = String.fromCharCodes(chunk);
      buffer.write(raw);

      final lines = buffer.toString().split('\n');
      buffer.clear();

      for (var i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.startsWith('data:')) {
          final jsonStr = line.substring(5).trim();
          try {
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
            // Ignore malformed chunks
          }
        }
      }

      if (lines.isNotEmpty) {
        buffer.write(lines.last);
      }
    }
  }
}
