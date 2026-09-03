import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/features/flashcards/domain/logic/fsrs_scheduler.dart';

/// Local-first card review sync queue that buffers logs locally and flushes
/// them in batches of 50 via idempotent RPC `upsert_fsrs_review_batch`.
class CardSyncQueue {
  CardSyncQueue({
    Dio? dio,
    Connectivity? connectivity,
    List<FsrsReviewLog>? initialBuffer,
    String? authToken,
  }) : _dio = dio ?? Dio(),
       _connectivity = connectivity ?? Connectivity(),
       _authToken = authToken,
       _inMemoryLogBuffer = initialBuffer != null
           ? List<FsrsReviewLog>.from(initialBuffer)
           : <FsrsReviewLog>[] {
    _initConnectivityListener();
  }

  final Dio _dio;
  final Connectivity _connectivity;
  final List<FsrsReviewLog> _inMemoryLogBuffer;
  final String? _authToken;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  Map<String, String> get _headers {
    final token = _authToken?.isNotEmpty == true ? _authToken! : AppEnv.apiKey;
    return {
      'apikey': AppEnv.apiKey,
      'Authorization': 'Bearer $token',
    };
  }

  static const int syncBatchSize = 50;
  bool _isSyncing = false;

  void _initConnectivityListener() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any(
        (c) =>
            c == ConnectivityResult.wifi ||
            c == ConnectivityResult.mobile ||
            c == ConnectivityResult.ethernet,
      );

      if (isOnline && _inMemoryLogBuffer.any((log) => !log.isSynced)) {
        unawaited(flushPendingLogs());
      }
    });
  }

  /// Appends a new review log to the local queue.
  Future<void> enqueueReview(FsrsReviewLog log) async {
    _inMemoryLogBuffer.add(log);
    debugPrint(
      '[CardSyncQueue] Log enqueued: ${log.transactionUuid}. '
      'Total pending: ${getPendingCount()}',
    );

    unawaited(flushPendingLogs());
  }

  /// Returns total number of unsynced review logs.
  int getPendingCount() {
    return _inMemoryLogBuffer.where((log) => !log.isSynced).length;
  }

  /// Flushes pending logs to database using the idempotent RPC
  /// in batches of 50.
  Future<int> flushPendingLogs() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    var syncedCount = 0;

    try {
      final pendingLogs = _inMemoryLogBuffer
          .where((log) => !log.isSynced)
          .toList();

      if (pendingLogs.isEmpty) {
        return 0;
      }

      for (var i = 0; i < pendingLogs.length; i += syncBatchSize) {
        final endIndex = (i + syncBatchSize < pendingLogs.length)
            ? i + syncBatchSize
            : pendingLogs.length;

        final batch = pendingLogs.sublist(i, endIndex);
        final payload = batch.map((log) => log.toSupabasePayload()).toList();

        try {
          await _dio.post<dynamic>(
            '${AppApiEndpoint.baseUri}/rest/v1/rpc/upsert_fsrs_review_batch',
            data: {'reviews': payload},
            options: Options(headers: _headers),
          );

          for (final syncedLog in batch) {
            final index = _inMemoryLogBuffer.indexWhere(
              (l) => l.transactionUuid == syncedLog.transactionUuid,
            );
            if (index != -1) {
              _inMemoryLogBuffer[index] = FsrsReviewLog(
                id: syncedLog.id,
                transactionUuid: syncedLog.transactionUuid,
                cardId: syncedLog.cardId,
                rating: syncedLog.rating,
                stability: syncedLog.stability,
                difficulty: syncedLog.difficulty,
                elapsedDays: syncedLog.elapsedDays,
                scheduledDays: syncedLog.scheduledDays,
                reviewedAtUtc: syncedLog.reviewedAtUtc,
                reviewedAtEpoch: syncedLog.reviewedAtEpoch,
                state: syncedLog.state,
                isSynced: true,
              );
            }
          }

          syncedCount += batch.length;
          debugPrint(
            '[CardSyncQueue] Idempotent RPC synced batch of '
            '${batch.length} logs.',
          );
        } on Object catch (rpcErr) {
          debugPrint('[CardSyncQueue] RPC sync failed: $rpcErr');

          try {
            await _dio.post<dynamic>(
              '${AppApiEndpoint.baseUri}/rest/v1/study_review_logs',
              data: payload,
              options: Options(
                headers: {
                  ..._headers,
                  'Prefer': 'resolution=merge-duplicates',
                },
              ),
            );
            for (final syncedLog in batch) {
              final index = _inMemoryLogBuffer.indexWhere(
                (l) => l.transactionUuid == syncedLog.transactionUuid,
              );
              if (index != -1) {
                _inMemoryLogBuffer[index] = FsrsReviewLog(
                  id: syncedLog.id,
                  transactionUuid: syncedLog.transactionUuid,
                  cardId: syncedLog.cardId,
                  rating: syncedLog.rating,
                  stability: syncedLog.stability,
                  difficulty: syncedLog.difficulty,
                  elapsedDays: syncedLog.elapsedDays,
                  scheduledDays: syncedLog.scheduledDays,
                  reviewedAtUtc: syncedLog.reviewedAtUtc,
                  reviewedAtEpoch: syncedLog.reviewedAtEpoch,
                  state: syncedLog.state,
                  isSynced: true,
                );
              }
            }
            syncedCount += batch.length;
          } on Object catch (fallbackErr) {
            debugPrint(
              '[CardSyncQueue] Direct upsert fallback error: $fallbackErr',
            );
            break;
          }
        }
      }
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }

  /// Clears synced records from memory buffer.
  void pruneSyncedLogs() {
    _inMemoryLogBuffer.removeWhere((log) => log.isSynced);
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
  }
}
