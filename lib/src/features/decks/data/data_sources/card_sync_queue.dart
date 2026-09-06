import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';

/// Local-first card review sync queue that buffers logs persistently and flushes
/// them in batches of 50 via idempotent RPC `upsert_fsrs_review_batch`.
class CardSyncQueue {
  CardSyncQueue({
    Dio? dio,
    Connectivity? connectivity,
    LocalStorageService? storageService,
    List<FsrsReviewLog>? initialBuffer,
    String? authToken,
  }) : _dio = dio ?? Dio(),
       _connectivity = connectivity ?? Connectivity(),
       _storageService = storageService ??
           (locator.isRegistered<LocalStorageService>()
               ? locator<LocalStorageService>()
               : null),
       _authToken = authToken,
       _inMemoryLogBuffer = initialBuffer != null
           ? List<FsrsReviewLog>.from(initialBuffer)
           : <FsrsReviewLog>[] {
    _loadPersistedLogs();
    _initConnectivityListener();
  }

  static const String storageKey = 'kortex_offline_fsrs_review_queue';

  final Dio _dio;
  final Connectivity _connectivity;
  final LocalStorageService? _storageService;
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

  void _loadPersistedLogs() {
    try {
      final raw = _storageService?.getPreference(key: storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final existingUuids =
              _inMemoryLogBuffer.map((l) => l.transactionUuid).toSet();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final log = FsrsReviewLog.fromMap(item);
              if (!existingUuids.contains(log.transactionUuid) && !log.isSynced) {
                _inMemoryLogBuffer.add(log);
              }
            } else if (item is Map) {
              final log =
                  FsrsReviewLog.fromMap(Map<String, dynamic>.from(item));
              if (!existingUuids.contains(log.transactionUuid) && !log.isSynced) {
                _inMemoryLogBuffer.add(log);
              }
            }
          }
        }
      }
    } on Object catch (e) {
      debugPrint('[CardSyncQueue] Failed to load persisted logs: $e');
    }
  }

  Future<void> _persistLogs() async {
    try {
      if (_storageService != null) {
        final pending = _inMemoryLogBuffer.where((l) => !l.isSynced).toList();
        if (pending.isEmpty) {
          await _storageService.deletePreference(key: storageKey);
        } else {
          final encoded = jsonEncode(pending.map((l) => l.toMap()).toList());
          await _storageService.savePreference(
            key: storageKey,
            data: encoded,
          );
        }
      }
    } on Object catch (e) {
      debugPrint('[CardSyncQueue] Failed to persist review logs: $e');
    }
  }

  void _initConnectivityListener() {
    try {
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
    } on Object catch (_) {
      // Ignored in test environments where platform binding is not initialized
    }
  }

  /// Appends a new review log to the local queue and persists to storage.
  Future<void> enqueueReview(FsrsReviewLog log) async {
    _inMemoryLogBuffer.add(log);
    await _persistLogs();
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

  /// Returns an unmodifiable list of currently pending (unsynced) review logs.
  List<FsrsReviewLog> get pendingLogs =>
      List.unmodifiable(_inMemoryLogBuffer.where((log) => !log.isSynced));

  /// Flushes pending logs to database using the idempotent RPC
  /// in batches of 50.
  Future<int> flushPendingLogs() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    var syncedCount = 0;

    try {
      final pendingLogs =
          _inMemoryLogBuffer.where((log) => !log.isSynced).toList();

      if (pendingLogs.isEmpty) {
        await _persistLogs();
        return 0;
      }

      for (var i = 0; i < pendingLogs.length; i += syncBatchSize) {
        final endIndex = (i + syncBatchSize < pendingLogs.length)
            ? i + syncBatchSize
            : pendingLogs.length;

        final batch = pendingLogs.sublist(i, endIndex);
        final payload = batch.map((log) {
          final p = log.toSupabasePayload();
          if (!UuidUtils.isValidUuid(p['transaction_uuid'] as String?)) {
            p['transaction_uuid'] = UuidUtils.generate();
          }
          if (!UuidUtils.isValidUuid(p['card_id'] as String?)) {
            p['card_id'] = UuidUtils.generate();
          }
          return p;
        }).toList();

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
      await _persistLogs();
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }

  /// Clears synced records from memory buffer.
  void pruneSyncedLogs() {
    _inMemoryLogBuffer.removeWhere((log) => log.isSynced);
    unawaited(_persistLogs());
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
  }
}
