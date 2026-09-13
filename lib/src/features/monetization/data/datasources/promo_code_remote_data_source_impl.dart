import 'package:dio/dio.dart';
import 'package:kortex/src/core/error/exceptions.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/features/monetization/data/datasources/promo_code_remote_data_source.dart';
import 'package:kortex/src/features/monetization/data/models/promo_code_model.dart';

class PromoCodeRemoteDataSourceImpl implements PromoCodeRemoteDataSource {
  const PromoCodeRemoteDataSourceImpl({
    required Dio dio,
  }) : _dio = dio;

  final Dio _dio;

  @override
  Future<PromoRedemptionResultModel> redeemPromoCode({
    required String code,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        AppApiEndpoint.redeemPromoCodeRpc,
        data: <String, dynamic>{
          'code_input': code.trim(),
        },
      );

      if (response.data is Map<String, dynamic>) {
        return PromoRedemptionResultModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      } else if (response.data is Map) {
        return PromoRedemptionResultModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }

      return const PromoRedemptionResultModel(
        success: false,
        errorCode: 'PARSE_ERROR',
        message: 'Unexpected server response format.',
      );
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        final map = Map<String, dynamic>.from(e.response!.data as Map);
        if (map.containsKey('message') || map.containsKey('error_code')) {
          return PromoRedemptionResultModel.fromJson(map);
        }
      }
      throw ServerException(
        message: e.message ?? 'Network error redeeming promo code.',
      );
    } on Object catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
        message: 'Failed to redeem promo code: $e',
      );
    }
  }
}
