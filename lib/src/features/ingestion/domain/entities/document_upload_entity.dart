import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';

/// Domain entity representing an uploaded study document with SHA-256
/// content deduplication.
class DocumentUploadEntity extends Equatable {
  const DocumentUploadEntity({
    required this.id,
    required this.userId,
    required this.filename,
    required this.fileType,
    required this.fileSizeBytes,
    required this.storagePath,
    required this.contentHash,
    required this.status,
    required this.createdAt,
    this.isDeduplicated = false,
  });

  final String id;
  final String userId;
  final String filename;
  final String fileType;
  final int fileSizeBytes;
  final String storagePath;
  final String contentHash;
  final ProcessingStatus status;
  final DateTime createdAt;
  final bool isDeduplicated;

  DocumentUploadEntity copyWith({
    String? id,
    String? userId,
    String? filename,
    String? fileType,
    int? fileSizeBytes,
    String? storagePath,
    String? contentHash,
    ProcessingStatus? status,
    DateTime? createdAt,
    bool? isDeduplicated,
  }) {
    return DocumentUploadEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      filename: filename ?? this.filename,
      fileType: fileType ?? this.fileType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      storagePath: storagePath ?? this.storagePath,
      contentHash: contentHash ?? this.contentHash,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      isDeduplicated: isDeduplicated ?? this.isDeduplicated,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    filename,
    fileType,
    fileSizeBytes,
    storagePath,
    contentHash,
    status,
    createdAt,
    isDeduplicated,
  ];
}
