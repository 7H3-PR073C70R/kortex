import 'package:dio/dio.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';

class SupabasePastQuestionsClient {
  SupabasePastQuestionsClient(this._dio);

  final Dio _dio;

  Map<String, String> get _headers => {
        'apikey': AppEnv.supabaseAnonKey,
        'Authorization': 'Bearer ${AppEnv.supabaseAnonKey}',
      };

  /// Queries past questions directly from Supabase `past_questions` table.
  Future<List<Map<String, dynamic>>> fetchPastQuestions({
    String? examType,
    String? subject,
    int? year,
    String? searchQuery,
    int limit = 100,
  }) async {
    final params = <String, dynamic>{
      'select': '*',
      'order': 'year.desc,question_number.asc',
      'limit': limit,
    };

    if (examType != null && examType.isNotEmpty && examType != 'ALL') {
      params['exam_type'] = 'ilike.%$examType%';
    }

    if (subject != null && subject.isNotEmpty && subject != 'All') {
      params['subject'] = 'ilike.%$subject%';
    }

    if (year != null) {
      params['year'] = 'eq.$year';
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      params['or'] = '(prompt.ilike.*$q*,topic.ilike.*$q*,subject.ilike.*$q*)';
    }

    final response = await _dio.get<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.pastQuestions}',
      queryParameters: params,
      options: Options(headers: _headers),
    );

    return (response.data ?? []).cast<Map<String, dynamic>>();
  }
}
