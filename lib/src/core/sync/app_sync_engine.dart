import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/decks/data/data_sources/card_sync_queue.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/planner/domain/repositories/planner_repository.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_repository.dart';

enum SyncStatus { online, syncing, offline }

class AppSyncPayload {
  AppSyncPayload({
    required this.id,
    required this.type,
    required this.data,
    required this.timestampEpoch,
  });

  factory AppSyncPayload.fromMap(Map<String, dynamic> map) {
    return AppSyncPayload(
      id: map['id'] as String,
      type: map['type'] as String,
      data: map['data'] as Map<String, dynamic>,
      timestampEpoch: map['timestampEpoch'] as int,
    );
  }

  final String id;
  final String type;
  final Map<String, dynamic> data;
  final int timestampEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'data': data,
      'timestampEpoch': timestampEpoch,
    };
  }
}

class AppSyncEngine {
  AppSyncEngine({
    Dio? dio,
    Connectivity? connectivity,
    LocalStorageService? storageService,
    UserStorageService? userStorageService,
  })  : _dio = dio ?? Dio(),
        _connectivity = connectivity ?? Connectivity(),
        _storageService = storageService ??
            (locator.isRegistered<LocalStorageService>()
                ? locator<LocalStorageService>()
                : null),
        _userStorageService = userStorageService ??
            (locator.isRegistered<UserStorageService>()
                ? locator<UserStorageService>()
                : null) {
    _loadPersistedPayloads();
    _initConnectivityListener();
  }

  static const String storageKey = 'kortex_global_sync_queue';
  static const int syncBatchSize = 50;

  final Dio _dio;
  final Connectivity _connectivity;
  final LocalStorageService? _storageService;
  final UserStorageService? _userStorageService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  
  final List<AppSyncPayload> _queue = [];
  bool _isSyncing = false;
  Completer<void>? _activeFlushCompleter;
  bool _isFullSyncInProgress = false;
  bool _hasPendingFullSync = false;
  Timer? _connectivityDebounceTimer;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  final _pendingCountController = StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  String? get currentAuthToken {
    final userToken = _userStorageService?.getToken();
    if (userToken != null && userToken.trim().isNotEmpty) {
      return userToken.trim();
    }
    return null;
  }

  Map<String, String>? get _headers {
    final token = currentAuthToken;
    if (token == null) return null;
    return {
      'apikey': AppEnv.apiKey,
      'Authorization': 'Bearer $token',
    };
  }

  void _loadPersistedPayloads() {
    try {
      final raw = _storageService?.getPreference(key: storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            _queue.add(AppSyncPayload.fromMap(item as Map<String, dynamic>));
          }
          _pendingCountController.add(_queue.length);
        }
      }
    } on Object catch (e, stack) {
      debugPrint('[AppSyncEngine] Failed to load persisted logs: $e\n$stack');
    }
  }

  Future<void> _persistQueue() async {
    try {
      if (_storageService != null) {
        if (_queue.isEmpty) {
          await _storageService.deletePreference(key: storageKey);
        } else {
          final encoded = jsonEncode(_queue.map((p) => p.toMap()).toList());
          await _storageService.savePreference(key: storageKey, data: encoded);
        }
        _pendingCountController.add(_queue.length);
      }
    } on Object catch (e, stack) {
      debugPrint('[AppSyncEngine] Failed to persist sync queue: $e\n$stack');
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

        _syncStatusController.add(isOnline ? SyncStatus.online : SyncStatus.offline);

        if (isOnline) {
          _connectivityDebounceTimer?.cancel();
          _connectivityDebounceTimer = Timer(const Duration(milliseconds: 300), () {
            unawaited(syncAll());
          });
        }
      });
    } on Object catch (e, st) { AppLogger.recordNonFatal(e, st); }
  }

  /// Dispatches full synchronization across all domain stores and queues
  /// when returning online. Guarantees strictly sequential execution to
  /// prevent concurrent SQLite locks or race conditions.
  Future<void> syncAll() async {
    if (_isFullSyncInProgress) {
      _hasPendingFullSync = true;
      return;
    }

    _isFullSyncInProgress = true;
    _syncStatusController.add(SyncStatus.syncing);

    try {
      do {
        _hasPendingFullSync = false;

        // 1. Flush AppSyncEngine CRDT payloads
        await flush();

        // 2. Flush CardSyncQueue FSRS review logs sequentially
        if (locator.isRegistered<CardSyncQueue>()) {
          try {
            await locator<CardSyncQueue>().flushPendingLogs();
          } on Object catch (e) {
            debugPrint('[AppSyncEngine] CardSyncQueue flush failed: $e');
          }
        }

        // 3. Flush QuizRepository pending submissions sequentially
        if (locator.isRegistered<QuizRepository>()) {
          try {
            await locator<QuizRepository>().flushPendingQuizSubmissions();
          } on Object catch (e) {
            debugPrint('[AppSyncEngine] QuizRepository flush failed: $e');
          }
        }

        // 4. Sync UserActivityService progress sequentially
        if (locator.isRegistered<UserActivityService>()) {
          try {
            await locator<UserActivityService>().syncPendingProgressToBackend();
          } on Object catch (e) {
            debugPrint('[AppSyncEngine] UserActivityService sync failed: $e');
          }
        }

        // 5. Flush CommunityRepository pending forum actions sequentially
        if (locator.isRegistered<CommunityRepository>()) {
          try {
            await locator<CommunityRepository>().flushPendingForumActions();
          } on Object catch (e) {
            debugPrint('[AppSyncEngine] CommunityRepository flush failed: $e');
          }
        }

        // 6. Refresh active planner exams
        if (locator.isRegistered<PlannerRepository>()) {
          try {
            await locator<PlannerRepository>().getActiveExams();
          } on Object catch (e) {
            debugPrint('[AppSyncEngine] PlannerRepository sync failed: $e');
          }
        }

        // 7. Refresh user decks
        if (locator.isRegistered<DecksRemoteDataSource>()) {
          try {
            await locator<DecksRemoteDataSource>().getUserDecks();
          } on Object catch (e) {
            debugPrint('[AppSyncEngine] DecksRemoteDataSource sync failed: $e');
          }
        }
      } while (_hasPendingFullSync);
    } finally {
      _isFullSyncInProgress = false;
      _syncStatusController.add(_queue.isEmpty ? SyncStatus.online : SyncStatus.offline);
    }
  }

  /// CRDT Field-Level Delta Merge helper
  AppSyncPayload mergeCrdtPayload(AppSyncPayload existing, AppSyncPayload incoming) {
    final mergedData = Map<String, dynamic>.from(existing.data);

    void mergeMap(Map<String, dynamic> target, Map<String, dynamic> source) {
      for (final entry in source.entries) {
        if (target.containsKey(entry.key) &&
            target[entry.key] is Map<String, dynamic> &&
            entry.value is Map<String, dynamic>) {
          mergeMap(
            target[entry.key] as Map<String, dynamic>,
            entry.value as Map<String, dynamic>,
          );
        } else {
          target[entry.key] = entry.value;
        }
      }
    }

    if (incoming.timestampEpoch >= existing.timestampEpoch) {
      mergeMap(mergedData, incoming.data);
    } else {
      final temp = Map<String, dynamic>.from(incoming.data);
      mergeMap(temp, mergedData);
      mergedData.addAll(temp);
    }

    final latestTimestamp = incoming.timestampEpoch > existing.timestampEpoch
        ? incoming.timestampEpoch
        : existing.timestampEpoch;

    return AppSyncPayload(
      id: incoming.id,
      type: incoming.type,
      data: mergedData,
      timestampEpoch: latestTimestamp,
    );
  }

  Future<void> enqueue(AppSyncPayload payload) async {
    final existingIndex = _queue.indexWhere((p) => p.id == payload.id && p.type == payload.type);
    if (existingIndex != -1) {
      _queue[existingIndex] = mergeCrdtPayload(_queue[existingIndex], payload);
    } else {
      _queue.add(payload);
    }

    await _persistQueue();
    unawaited(flush());
  }

  /// Flushes all pending outbox records, review logs, and progress to Supabase
  /// sequentially before session teardown or logout.
  Future<void> flushAllPendingOutboxes() async {
    // 1. Flush AppSyncEngine CRDT payloads
    await flush();

    // 2. Flush CardSyncQueue FSRS review logs sequentially
    if (locator.isRegistered<CardSyncQueue>()) {
      try {
        await locator<CardSyncQueue>().flushPendingLogs();
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }

    // 3. Flush QuizRepository pending submissions sequentially
    if (locator.isRegistered<QuizRepository>()) {
      try {
        await locator<QuizRepository>().flushPendingQuizSubmissions();
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }

    // 4. Sync UserActivityService progress sequentially
    if (locator.isRegistered<UserActivityService>()) {
      try {
        await locator<UserActivityService>().syncPendingProgressToBackend();
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }

    // 5. Flush CommunityRepository pending forum actions sequentially
    if (locator.isRegistered<CommunityRepository>()) {
      try {
        await locator<CommunityRepository>().flushPendingForumActions();
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }
  }

  Future<void> flush() async {
    while (_isSyncing) {
      await _activeFlushCompleter?.future;
    }
    if (_queue.isEmpty) return;

    _isSyncing = true;
    _activeFlushCompleter = Completer<void>();
    _syncStatusController.add(SyncStatus.syncing);

    final headers = _headers;
    if (headers == null) {
      _isSyncing = false;
      _activeFlushCompleter?.complete();
      _activeFlushCompleter = null;
      _syncStatusController.add(SyncStatus.online);
      return;
    }

    final toSync = List<AppSyncPayload>.from(_queue);

    try {
      for (var i = 0; i < toSync.length; i += syncBatchSize) {
        final end = (i + syncBatchSize < toSync.length) ? i + syncBatchSize : toSync.length;
        final batch = toSync.sublist(i, end);

        final requestPayload = batch.map((p) => p.toMap()).toList();

        await _postWithExponentialBackoff(
          url: '${AppApiEndpoint.baseUri}/rest/v1/rpc/app_sync_engine_upsert',
          data: {'payloads': requestPayload},
          headers: headers,
        );

        _queue.removeWhere((p) => batch.any((b) => b.id == p.id));
      }
    } on Object catch (e, stack) {
      AppLogger.error(
        'AppSyncEngine flush error: $e',
        tag: 'AppSyncEngine',
        error: e,
        stackTrace: stack,
      );
    } finally {
      await _persistQueue();
      _isSyncing = false;
      final comp = _activeFlushCompleter;
      _activeFlushCompleter = null;
      comp?.complete();
      _syncStatusController.add(_queue.isEmpty ? SyncStatus.online : SyncStatus.offline);
    }
  }

  Future<void> _postWithExponentialBackoff({
    required String url,
    required Map<String, dynamic> data,
    required Map<String, String> headers,
    int maxRetries = 3,
  }) async {
    var attempts = 0;
    while (true) {
      try {
        await _dio.post<dynamic>(
          url,
          data: data,
          options: Options(headers: headers),
        );
        return;
      } on Object catch (_) {
        attempts++;
        if (attempts > maxRetries) {
          rethrow;
        }
        final backoffMs = 150 * (1 << attempts);
        await Future<void>.delayed(Duration(milliseconds: backoffMs));
      }
    }
  }

  Future<void> dispose() async {
    _connectivityDebounceTimer?.cancel();
    await _connectivitySub?.cancel();
    await _syncStatusController.close();
    await _pendingCountController.close();
  }
}
