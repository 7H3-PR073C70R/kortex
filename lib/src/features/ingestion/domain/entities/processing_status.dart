/// Document ingestion and STEM OCR parsing lifecycle status.
enum ProcessingStatus {
  idle,
  uploading,
  parsingOcr,
  generatingCards,
  completed,
  failed,
}

extension ProcessingStatusX on ProcessingStatus {
  String get nameString {
    switch (this) {
      case ProcessingStatus.idle:
        return 'idle';
      case ProcessingStatus.uploading:
        return 'uploaded';
      case ProcessingStatus.parsingOcr:
        return 'parsingOcr';
      case ProcessingStatus.generatingCards:
        return 'generatingCards';
      case ProcessingStatus.completed:
        return 'completed';
      case ProcessingStatus.failed:
        return 'failed';
    }
  }

  static ProcessingStatus fromString(String value) {
    switch (value) {
      case 'uploaded':
      case 'uploading':
        return ProcessingStatus.uploading;
      case 'parsingOcr':
        return ProcessingStatus.parsingOcr;
      case 'generatingCards':
        return ProcessingStatus.generatingCards;
      case 'completed':
        return ProcessingStatus.completed;
      case 'failed':
        return ProcessingStatus.failed;
      case 'idle':
      default:
        return ProcessingStatus.idle;
    }
  }
}
