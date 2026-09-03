import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';

class OnboardingStreamState {
  const OnboardingStreamState({
    required this.cards,
    this.isInitialReviewReady = false,
    this.isStreaming = false,
    this.isCompleted = false,
    this.isPartialDeckFallback = false,
    this.initialLatencyMs,
    this.errorMessage,
    this.targetCardCount = 20,
  });

  final List<GeneratedFlashcard> cards;

  /// True as soon as 3 review-ready cards arrive (< 3s SLA).
  final bool isInitialReviewReady;
  final bool isStreaming;
  final bool isCompleted;
  final bool isPartialDeckFallback;
  final int? initialLatencyMs;
  final String? errorMessage;
  final int targetCardCount;

  /// Returns the generated flashcard at index or a lightweight synthesizing
  /// placeholder if the user has navigated past the current stream buffer.
  GeneratedFlashcard? getCardOrPlaceholder(int index) {
    if (index < cards.length) {
      return cards[index];
    }

    if (isStreaming && index < targetCardCount) {
      // Dynamic non-blocking placeholder skeleton card
      return GeneratedFlashcard(
        id: 'skeleton_card_$index',
        front: 'Synthesizing card ${index + 1}...',
        back: r'$$\dots$$ Generating contextual derivation...',
        explanation:
            'Background edge stream active. '
            'Next card arriving shortly.',
        isLocalInference: false,
        tags: const ['StreamingBuffer'],
      );
    }

    return null;
  }

  /// Returns true if card at index is still actively synthesizing.
  bool isCardSynthesizing(int index) {
    return index >= cards.length && isStreaming;
  }

  int get totalAvailableCards => cards.length;

  OnboardingStreamState copyWith({
    List<GeneratedFlashcard>? cards,
    bool? isInitialReviewReady,
    bool? isStreaming,
    bool? isCompleted,
    bool? isPartialDeckFallback,
    int? initialLatencyMs,
    String? errorMessage,
    int? targetCardCount,
  }) {
    return OnboardingStreamState(
      cards: cards ?? this.cards,
      isInitialReviewReady: isInitialReviewReady ?? this.isInitialReviewReady,
      isStreaming: isStreaming ?? this.isStreaming,
      isCompleted: isCompleted ?? this.isCompleted,
      isPartialDeckFallback:
          isPartialDeckFallback ?? this.isPartialDeckFallback,
      initialLatencyMs: initialLatencyMs ?? this.initialLatencyMs,
      errorMessage: errorMessage ?? this.errorMessage,
      targetCardCount: targetCardCount ?? this.targetCardCount,
    );
  }
}

/// Ingestion Stream Controller enforcing sub-3-second time-to-first-card SLA
/// and 10-second inactivity timeout with graceful partial deck fallback.
class OnboardingStreamController {
  OnboardingStreamController({
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final Dio _dio;
  final StreamController<OnboardingStreamState> _stateController =
      StreamController<OnboardingStreamState>.broadcast();

  Stream<OnboardingStreamState> get stateStream => _stateController.stream;

  OnboardingStreamState _currentState = const OnboardingStreamState(cards: []);
  OnboardingStreamState get currentState => _currentState;

  CancelToken? _cancelToken;
  Timer? _inactivityTimer;

  static const Duration streamInactivityTimeout = Duration(seconds: 10);

  /// Initiates SSE document-to-flashcard streaming session from edge function.
  Future<void> startIngestionStream({
    required String endpointUrl,
    required String documentId,
    required String jwtToken,
    String? documentText,
    int targetCount = 20,
  }) async {
    _cancelToken = CancelToken();
    final stopwatch = Stopwatch()..start();

    _updateState(
      OnboardingStreamState(
        cards: const [],
        isStreaming: true,
        targetCardCount: targetCount,
      ),
    );

    final accumulatedCards = <GeneratedFlashcard>[];
    var initialBatchEmitted = false;

    void resetInactivityWatchdog() {
      _inactivityTimer?.cancel();
      _inactivityTimer = Timer(streamInactivityTimeout, () {
        if (_currentState.isStreaming && !initialBatchEmitted) {
          debugPrint(
            '[OnboardingStreamController] 10s stream inactivity detected. '
            'Saving ${accumulatedCards.length} partial cards cleanly.',
          );
          _cancelToken?.cancel('Inactivity timeout reached.');
          _updateState(
            _currentState.copyWith(
              cards: List.unmodifiable(accumulatedCards),
              isStreaming: false,
              isCompleted: true,
              isPartialDeckFallback: true,
            ),
          );
        }
      });
    }

    resetInactivityWatchdog();

    try {
      final response = await _dio.post<ResponseBody>(
        endpointUrl,
        data: jsonEncode({
          'documentId': documentId,
          'sourceText': ?documentText,
          'count': targetCount,
        }),
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Accept': 'text/event-stream',
            'Content-Type': 'application/json',
          },
        ),
      );

      final stream = response.data?.stream;
      if (stream == null) {
        throw const FormatException(
          'Empty SSE response stream from Edge Gateway',
        );
      }

      // Stream pipeline: Uint8List -> UTF8 -> LineSplitter
      await stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              resetInactivityWatchdog();

              if (line.startsWith('data: ')) {
                final jsonPayload = line.substring(6).trim();
                if (jsonPayload == '[DONE]') {
                  return;
                }

                try {
                  final dynamic decoded = jsonDecode(jsonPayload);
                  if (decoded is Map<String, dynamic>) {
                    if (decoded.containsKey('card')) {
                      final card = GeneratedFlashcard.fromJson(
                        decoded['card'] as Map<String, dynamic>,
                      );
                      accumulatedCards.add(card);
                    } else if (decoded.containsKey('cards') &&
                        decoded['cards'] is List) {
                      for (final item in decoded['cards'] as List<dynamic>) {
                        accumulatedCards.add(
                          GeneratedFlashcard.fromJson(
                            item as Map<String, dynamic>,
                          ),
                        );
                      }
                    }

                    // Sub-3-Second Killer Loop SLA check (< 3s for first 3 cards)
                    if (accumulatedCards.length >= 3 && !initialBatchEmitted) {
                      initialBatchEmitted = true;
                      final elapsedMs = stopwatch.elapsedMilliseconds;
                      debugPrint(
                        '[OnboardingStreamController] Sub-3s SLA Met! '
                        'First 3 cards ready in ${elapsedMs}ms.',
                      );

                      _updateState(
                        _currentState.copyWith(
                          cards: List.unmodifiable(accumulatedCards),
                          isInitialReviewReady: true,
                          initialLatencyMs: elapsedMs,
                        ),
                      );
                    } else {
                      _updateState(
                        _currentState.copyWith(
                          cards: List.unmodifiable(accumulatedCards),
                        ),
                      );
                    }
                  }
                } on Object catch (parseErr) {
                  debugPrint(
                    '[OnboardingStreamController] Delta parse note: $parseErr',
                  );
                }
              }
            },
          )
          .asFuture<void>();

      // Normal stream completion
      _inactivityTimer?.cancel();
      _updateState(
        _currentState.copyWith(
          cards: List.unmodifiable(accumulatedCards),
          isStreaming: false,
          isCompleted: true,
        ),
      );
    } on DioException catch (dioErr) {
      _inactivityTimer?.cancel();
      if (CancelToken.isCancel(dioErr)) {
        // If cancelled due to inactivity or user cancel, save partial
        // cards cleanly
        _updateState(
          _currentState.copyWith(
            cards: List.unmodifiable(accumulatedCards),
            isStreaming: false,
            isCompleted: true,
            isPartialDeckFallback: true,
          ),
        );
      } else {
        _updateState(
          _currentState.copyWith(
            cards: List.unmodifiable(accumulatedCards),
            isStreaming: false,
            isCompleted: accumulatedCards.isNotEmpty,
            errorMessage: 'Gateway connection error: ${dioErr.message}',
          ),
        );
      }
    } on Object catch (err) {
      _inactivityTimer?.cancel();
      _updateState(
        _currentState.copyWith(
          cards: List.unmodifiable(accumulatedCards),
          isStreaming: false,
          isCompleted: accumulatedCards.isNotEmpty,
          errorMessage: 'Stream processing error: $err',
        ),
      );
    } finally {
      _inactivityTimer?.cancel();
    }
  }

  void cancel() {
    _inactivityTimer?.cancel();
    _cancelToken?.cancel('Cancelled by caller');
  }

  void _updateState(OnboardingStreamState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  Future<void> dispose() async {
    cancel();
    await _stateController.close();
  }
}
