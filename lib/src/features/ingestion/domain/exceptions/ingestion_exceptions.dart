/// Custom exceptions for document ingestion, extraction, and parsing.
library;

/// Thrown when an unsupported file extension is passed to the ingestion engine.
class UnsupportedFileTypeException implements Exception {
  const UnsupportedFileTypeException(this.extension);
  final String extension;

  @override
  String toString() =>
      'UnsupportedFileTypeException: File type ".$extension" is not supported';
}

/// Thrown when a PDF is encrypted or password-protected.
class EncryptedPdfException implements Exception {
  const EncryptedPdfException(
    this.filename, [
    this.message = 'PDF document is password protected or encrypted.',
  ]);

  final String filename;
  final String message;

  @override
  String toString() => 'EncryptedPdfException($filename): $message';
}

/// Thrown when a document has malformed or corrupt syntax and cannot be parsed.
class CorruptDocumentException implements Exception {
  const CorruptDocumentException(
    this.filename, [
    this.message = 'Document structure is corrupt or malformed.',
  ]);

  final String filename;
  final String message;

  @override
  String toString() => 'CorruptDocumentException($filename): $message';
}

/// Thrown when a document contains scanned bitmap images without embedded text streams.
class ScannedDocumentException implements Exception {
  const ScannedDocumentException(
    this.filename, [
    this.message =
        'Document contains scanned images without embedded text streams. OCR required.',
  ]);

  final String filename;
  final String message;

  @override
  String toString() => 'ScannedDocumentException($filename): $message';
}

/// Thrown when document extraction exceeds maximum file size limit.
class FileSizeExceededException implements Exception {
  const FileSizeExceededException([
    this.message = 'File exceeds maximum 50MB limit',
  ]);

  final String message;

  @override
  String toString() => 'FileSizeExceededException: $message';
}

/// Generic document extraction failure.
class DocumentExtractionException implements Exception {
  const DocumentExtractionException(this.message);

  final String message;

  @override
  String toString() => 'DocumentExtractionException: $message';
}

/// Thrown when document processing is cancelled via cancellation token.
class IngestionCancelledException implements Exception {
  const IngestionCancelledException([
    this.message = 'Ingestion task was cancelled by user.',
  ]);

  final String message;

  @override
  String toString() => 'IngestionCancelledException: $message';
}

/// Thrown when document extraction exceeds execution or memory budget.
class IngestionBudgetException implements Exception {
  const IngestionBudgetException(this.message);

  final String message;

  @override
  String toString() => 'IngestionBudgetException: $message';
}
