import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/flashcards/domain/logic/fsrs_scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Local-first card review sync queue that buffers logs locally and flushes
/// them in batches of 50 via idempotent RPC `upsert_fsrs_review_batch`.
class CardSyncQueue {
  CardSyncQueue({
    SupabaseClient? supabaseClient,
    Connectivity? connectivity,
    List<FsrsReviewLog>? initialBuffer,
  })  : _supabase = supabaseClient,
        _connectivity = connectivity ?? Connectivity(),
        _inMemoryLogBuffer = initialBuffer != null
            ? List<FsrsReviewLog>.from(initialBuffer)
            : <FsrsReviewLog>[] {
    _initConnectivityListener();
  }

  final SupabaseClient? _supabase;
  final Connectivity _connectivity;
  final List<FsrsReviewLog> _inMemoryLogBuffer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  SupabaseClient? get _client {
    if (_supabase != null) return _supabase;
    try {
      return Supabase.instance.client;
    } on Object {
      return null;
    }
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

    // Proactive sync attempt if online
    unawaited(flushPendingLogs());
  }

  /// Returns total number of unsynced review logs.
  int getPendingCount() {
    return _inMemoryLogBuffer.where((log) => !log.isSynced).length;
  }

  /// Flushes pending logs to Supabase Postgres using the idempotent RPC
  /// in batches of 50.
  Future<int> flushPendingLogs() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    var syncedCount = 0;

    try {
      final client = _client;
      if (client == null) {
        debugPrint(
          '[CardSyncQueue] Supabase client unavailable. Deferring sync.',
        );
        return 0;
      }

      final pendingLogs =
          _inMemoryLogBuffer.where((log) => !log.isSynced).toList();

      if (pendingLogs.isEmpty) {
        return 0;
      }

      // Process in batches of 50
      for (var i = 0; i < pendingLogs.length; i += syncBatchSize) {
        final endIndex = (i + syncBatchSize < pendingLogs.length)
            ? i + syncBatchSize
            : pendingLogs.length;

        final batch = pendingLogs.sublist(i, endIndex);
        final payload = batch.map((log) => log.toSupabasePayload()).toList();

        try {
          // 1. Primary: Call idempotent Supabase Postgres RPC function
          await client.rpc<dynamic>(
            'upsert_fsrs_review_batch',
            params: {'reviews': payload},
          );

          // Mark batch as synced locally
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

          // Fallback direct upsert
          try {
            await client.from('study_review_logs').upsert(payload);
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
            break; // Stop and retry on next connectivity cycle
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
