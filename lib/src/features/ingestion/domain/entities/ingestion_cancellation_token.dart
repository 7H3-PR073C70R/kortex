import 'package:kortex/src/features/ingestion/domain/exceptions/ingestion_exceptions.dart';

/// Cooperative cancellation token allowing long-running ingestion, OCR,
/// or PDF extraction processes to be cancelled cooperatively.
class IngestionCancellationToken {
  IngestionCancellationToken();

  bool _isCancelled = false;
  String? _reason;
  final List<void Function()> _listeners = [];

  /// Whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// The reason why cancellation was requested, if available.
  String? get reason => _reason;

  /// Requests cooperative cancellation of the ongoing ingestion task.
  void cancel([String reason = 'Ingestion task was cancelled.']) {
    if (_isCancelled) return;
    _isCancelled = true;
    _reason = reason;
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Adds a callback invoked when cancellation is triggered.
  void addListener(void Function() listener) {
    if (_isCancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  /// Throws [IngestionCancelledException] if cancellation was requested.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw IngestionCancelledException(_reason ?? 'Ingestion task was cancelled.');
    }
  }
}
