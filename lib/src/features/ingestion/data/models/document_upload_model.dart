import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';

class DocumentUploadModel {
  const DocumentUploadModel({
    required this.id,
    required this.userId,
    required this.filename,
    required this.fileType,
    required this.fileSizeBytes,
    required this.storagePath,
    required this.contentHash,
    required this.processingStatus,
    required this.createdAt,
    this.isDeduplicated = false,
    this.deckId,
    this.courseId,
    this.courseCode,
  });

  factory DocumentUploadModel.fromJson(
    Map<String, dynamic> json, {
    bool isDeduplicated = false,
    String? deckId,
  }) {
    return DocumentUploadModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      filename: json['filename'] as String,
      fileType: json['file_type'] as String,
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      storagePath: json['storage_path'] as String,
      contentHash: json['content_hash'] as String? ?? '',
      processingStatus: json['processing_status'] as String? ?? 'uploaded',
      createdAt: DateTime.parse(json['created_at'] as String),
      isDeduplicated: isDeduplicated,
      deckId: deckId ?? json['deck_id'] as String?,
      courseId: json['course_id'] as String?,
      courseCode: json['course_code'] as String?,
    );
  }

  factory DocumentUploadModel.fromEntity(DocumentUploadEntity entity) {
    return DocumentUploadModel(
      id: entity.id,
      userId: entity.userId,
      filename: entity.filename,
      fileType: entity.fileType,
      fileSizeBytes: entity.fileSizeBytes,
      storagePath: entity.storagePath,
      contentHash: entity.contentHash,
      processingStatus: entity.status.nameString,
      createdAt: entity.createdAt,
      isDeduplicated: entity.isDeduplicated,
      deckId: entity.deckId,
      courseId: entity.courseId,
      courseCode: entity.courseCode,
    );
  }

  final String id;
  final String userId;
  final String filename;
  final String fileType;
  final int fileSizeBytes;
  final String storagePath;
  final String contentHash;
  final String processingStatus;
  final DateTime createdAt;
  final bool isDeduplicated;
  final String? deckId;
  final String? courseId;
  final String? courseCode;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'filename': filename,
      'file_type': fileType,
      'file_size_bytes': fileSizeBytes,
      'storage_path': storagePath,
      'content_hash': contentHash,
      'processing_status': processingStatus,
      'created_at': createdAt.toIso8601String(),
      if (deckId != null) 'deck_id': deckId,
      if (courseId != null) 'course_id': courseId,
      if (courseCode != null) 'course_code': courseCode,
    };
  }

  DocumentUploadEntity toEntity() {
    return DocumentUploadEntity(
      id: id,
      userId: userId,
      filename: filename,
      fileType: fileType,
      fileSizeBytes: fileSizeBytes,
      storagePath: storagePath,
      contentHash: contentHash,
      status: ProcessingStatusX.fromString(processingStatus),
      createdAt: createdAt,
      isDeduplicated: isDeduplicated,
      deckId: deckId,
      courseId: courseId,
      courseCode: courseCode,
    );
  }
}
