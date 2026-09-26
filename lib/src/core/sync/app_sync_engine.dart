import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';

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
  
  final List<AppSyncPayload> _queue = [];
  bool _isSyncing = false;

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
    _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any(
        (c) =>
            c == ConnectivityResult.wifi ||
            c == ConnectivityResult.mobile ||
            c == ConnectivityResult.ethernet,
      );

      _syncStatusController.add(isOnline ? SyncStatus.online : SyncStatus.offline);

      if (isOnline && _queue.isNotEmpty) {
        unawaited(flush());
      }
    });
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

  Future<void> flush() async {
    if (_isSyncing || _queue.isEmpty) return;
    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);

    final headers = _headers;
    if (headers == null) {
      _isSyncing = false;
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
      debugPrint('[AppSyncEngine] Flush error after retries: $e\n$stack');
    } finally {
      await _persistQueue();
      _isSyncing = false;
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
    await _syncStatusController.close();
    await _pendingCountController.close();
  }
}
