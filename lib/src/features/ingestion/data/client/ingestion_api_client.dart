import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:retrofit/retrofit.dart';

part 'ingestion_api_client.g.dart';

@RestApi()
abstract class IngestionApiClient {
  factory IngestionApiClient(Dio dio, {String baseUrl}) = _IngestionApiClient;

  @POST(AppApiEndpoint.findOrCreateDocumentReference)
  Future<HttpResponse<dynamic>> findOrCreateDocumentReference(
    @Body() Map<String, dynamic> body,
  );

  @POST(AppApiEndpoint.claimOrCreateDocumentPreflight)
  Future<HttpResponse<dynamic>> claimOrCreateDocumentPreflight(
    @Body() Map<String, dynamic> body,
  );

  @GET(AppApiEndpoint.documents)
  Future<HttpResponse<dynamic>> fetchDocuments(
    @Queries() Map<String, dynamic> query,
  );

  @POST(AppApiEndpoint.documents)
  Future<HttpResponse<dynamic>> createDocumentRecord(
    @Body() Map<String, dynamic> body, {
    @Header('Prefer') String prefer = 'return=representation',
  });

  @POST(AppApiEndpoint.parseStemOcr)
  Future<HttpResponse<dynamic>> triggerParseStemOcr(
    @Body() Map<String, dynamic> body,
  );

  @GET(AppApiEndpoint.extractedSnippets)
  Future<HttpResponse<dynamic>> fetchExtractedSnippets(
    @Queries() Map<String, dynamic> query,
  );

  @POST(AppApiEndpoint.getAiSmartGenQuota)
  Future<HttpResponse<dynamic>> getAiSmartGenQuota(
    @Body() Map<String, dynamic> body,
  );

  @POST(AppApiEndpoint.recordAiSmartGenUsage)
  Future<HttpResponse<dynamic>> recordAiSmartGenUsage(
    @Body() Map<String, dynamic> body,
  );
}


/// Helper extension for binary file uploads to Storage bucket.
extension IngestionStorageUpload on Dio {
  Future<void> uploadStorageFile({
    required String storagePath,
    required Uint8List fileBytes,
    required String contentType,
    String bucket = AppApiEndpoint.storageBucket,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      await post<dynamic>(
        '${AppApiEndpoint.baseUri}$bucket/$storagePath',
        data: fileBytes,
        options: Options(
          extra: {'silent': true},
          headers: {
            'Content-Type': contentType,
            'x-upsert': 'true',
          },
        ),
        onSendProgress: onProgress,
      );
    } on DioException catch (e) {
      final resData = e.response?.data;
      final isAlreadyExists = e.response?.statusCode == 409 ||
          (e.response?.statusCode == 400 &&
              resData is Map &&
              (resData['code'] == 'KeyAlreadyExists' ||
                  resData['error'] == 'Duplicate' ||
                  resData['statusCode'] == 409 ||
                  resData['statusCode'] == '409'));

      if (isAlreadyExists) {
        // Resource already safely stored in Content-Addressable Storage (CAS)
        return;
      }
      rethrow;
    }
  }

  /// Uploads an extracted document diagram/image to Cloudflare R2
  /// under `documents/{documentId}/images/{filename}`.
  Future<String?> uploadDocumentImageToR2({
    required String documentId,
    required String filename,
    required Uint8List fileBytes,
    required String contentType,
    String? token,
  }) async {
    final response = await post<Map<String, dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.uploadForumMedia}',
      data: fileBytes,
      options: Options(
        extra: {'silent': true},
        headers: {
          'Content-Type': contentType,
          'x-media-type': 'document_image',
          'x-document-id': documentId,
          'x-file-name': filename,
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode == 200 && response.data != null) {
      final resData = response.data!;
      return resData['url'] as String? ?? resData['proxyUrl'] as String?;
    }
    return null;
  }
}
