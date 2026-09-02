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
  }
}
