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

  Future<void> enqueue(AppSyncPayload payload) async {
    final existingIndex = _queue.indexWhere((p) => p.id == payload.id && p.type == payload.type);
    if (existingIndex != -1) {
      if (payload.timestampEpoch > _queue[existingIndex].timestampEpoch) {
        _queue[existingIndex] = payload;
      }
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
        
        await _dio.post<dynamic>(
          '${AppApiEndpoint.baseUri}/rest/v1/rpc/app_sync_engine_upsert',
          data: {'payloads': requestPayload},
          options: Options(headers: headers),
        );
        
        _queue.removeWhere((p) => batch.any((b) => b.id == p.id));
      }
    } on Object catch (e, stack) {
      debugPrint('[AppSyncEngine] Flush error: $e\n$stack');
    } finally {
      await _persistQueue();
      _isSyncing = false;
      _syncStatusController.add(_queue.isEmpty ? SyncStatus.online : SyncStatus.offline);
    }
  }

  Future<void> dispose() async {
    await _syncStatusController.close();
    await _pendingCountController.close();
  }
}
