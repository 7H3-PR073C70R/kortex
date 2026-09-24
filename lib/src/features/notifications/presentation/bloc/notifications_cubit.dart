import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    NotificationService? notificationService,
    Dio? dio,
    UserStorageService? userStorageService,
    LocalStorageService? localStorageService,
  })  : _notificationService = notificationService,
        _dio = dio,
        _userStorageService = userStorageService,
        _localStorageService = localStorageService,
        super(const NotificationsState()) {
    _initSubscription();
    unawaited(loadNotifications());
  }

  static const String _cacheKey = '__kortex_notifications_inbox__';

  final NotificationService? _notificationService;
  final Dio? _dio;
  final UserStorageService? _userStorageService;
  final LocalStorageService? _localStorageService;
  StreamSubscription<dynamic>? _messageSubscription;

  void _initSubscription() {
    try {
      final service = _notificationService ??
          (locator.isRegistered<NotificationService>()
              ? locator<NotificationService>()
              : null);
      if (service != null) {
        _messageSubscription = service.onMessage.listen((remoteMessage) {
          final title = remoteMessage.notification?.title ?? 'Kortex Update';
          final body = remoteMessage.notification?.body ?? '';
          final payload = remoteMessage.data['route']?.toString() ??
              remoteMessage.data['payload']?.toString();

          addNotification(
            NotificationItemEntity(
              id: remoteMessage.messageId ??
                  'remote_${DateTime.now().millisecondsSinceEpoch}',
              title: title,
              message: body,
              timestamp: DateTime.now(),
              category: NotificationCategoryExtension.fromString(
                remoteMessage.data['category']?.toString(),
              ),
              actionRoute: payload,
              metadata: remoteMessage.data,
            ),
          );
        });
      }
    } on Object catch (_) {}
  }

  /// Loads real notifications from local cache and the backend API.
  Future<void> loadNotifications({bool forceRefresh = false}) async {
    emit(state.copyWith(status: NotificationsStatus.loading));

    final localStore = _localStorageService ??
        (locator.isRegistered<LocalStorageService>()
            ? locator<LocalStorageService>()
            : null);

    // 1. Instantly populate from local cache if available
    if (localStore != null) {
      final cachedJson = localStore.getPreference(key: _cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedJson);
          if (decoded is List) {
            final cachedItems = decoded
                .whereType<Map<dynamic, dynamic>>()
                .map((m) => NotificationItemEntity.fromJson(
                      Map<String, dynamic>.from(m),
                    ))
                .toList();
            if (cachedItems.isNotEmpty && state.notifications.isEmpty) {
              emit(state.copyWith(
                status: NotificationsStatus.loaded,
                notifications: cachedItems,
              ));
            }
          }
        } on Object catch (_) {}
      }
    }

    // 2. Fetch live notifications from Supabase backend
    try {
      final dio = _dio ??
          (locator.isRegistered<Dio>() ? locator<Dio>() : null);

      if (dio != null) {
        final res = await dio.get<dynamic>(
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.notificationsInbox}',
        );

        final data = res.data;
        final rawList = <dynamic>[];
        if (data is List) {
          rawList.addAll(data);
        } else if (data is Map &&
            data.containsKey('data') &&
            data['data'] is List) {
          rawList.addAll(data['data'] as List);
        }

        final remoteNotifications = rawList
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => NotificationItemEntity.fromJson(
                  Map<String, dynamic>.from(m),
                ))
            .toList();

        // Persist to local storage
        if (localStore != null) {
          final encoded = jsonEncode(
            remoteNotifications.map((n) => n.toJson()).toList(),
          );
          unawaited(localStore.savePreference(key: _cacheKey, data: encoded));
        }

        emit(state.copyWith(
          status: NotificationsStatus.loaded,
          notifications: remoteNotifications,
        ));
        return;
      }
    } on Object catch (e) {
      debugPrint('[NotificationsCubit] Remote notifications fetch note: $e');
    }

    // 3. Fallback: retain cached items or set loaded status with empty list
    emit(state.copyWith(
      status: NotificationsStatus.loaded,
      notifications: state.notifications,
    ));
  }

  void addNotification(NotificationItemEntity notification) {
    final updated = [notification, ...state.notifications];
    emit(state.copyWith(notifications: updated));
    _persistCache(updated);
  }

  Future<void> markAsRead(String id) async {
    final updated = state.notifications.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    emit(state.copyWith(notifications: updated));
    _persistCache(updated);

    try {
      final dio = _dio ??
          (locator.isRegistered<Dio>() ? locator<Dio>() : null);
      if (dio != null) {
        await dio.patch<dynamic>(
          '${AppApiEndpoint.baseUri}/rest/v1/notifications?id=eq.$id',
          data: {'read': true},
        );
      }
    } on Object catch (e) {
      debugPrint('[NotificationsCubit] markAsRead error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final updated =
        state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    emit(state.copyWith(notifications: updated));
    _persistCache(updated);

    try {
      final dio = _dio ??
          (locator.isRegistered<Dio>() ? locator<Dio>() : null);
      final userStore = _userStorageService ??
          (locator.isRegistered<UserStorageService>()
              ? locator<UserStorageService>()
              : null);
      final userId = userStore?.getUserId();
      if (dio != null) {
        final query = (userId != null && userId.isNotEmpty)
            ? 'user_id=eq.$userId&read=eq.false'
            : 'read=eq.false';
        await dio.patch<dynamic>(
          '${AppApiEndpoint.baseUri}/rest/v1/notifications?$query',
          data: {'read': true},
        );
      }
    } on Object catch (e) {
      debugPrint('[NotificationsCubit] markAllAsRead error: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    final updated = state.notifications.where((n) => n.id != id).toList();
    emit(state.copyWith(notifications: updated));
    _persistCache(updated);

    try {
      final dio = _dio ??
          (locator.isRegistered<Dio>() ? locator<Dio>() : null);
      if (dio != null) {
        await dio.delete<dynamic>(
          '${AppApiEndpoint.baseUri}/rest/v1/notifications?id=eq.$id',
        );
      }
    } on Object catch (e) {
      debugPrint('[NotificationsCubit] deleteNotification error: $e');
    }
  }

  void clearAll() {
    emit(state.copyWith(notifications: []));
    _persistCache([]);
  }

  void showAll() {
    emit(state.copyWith(
      selectedCategory: NotificationCategory.all,
      onlyUnread: false,
    ));
  }

  void selectCategory(NotificationCategory category) {
    emit(state.copyWith(
      selectedCategory: category,
      onlyUnread: false,
    ));
  }

  void filterByCategory(NotificationCategory category) {
    emit(state.copyWith(
      selectedCategory: category,
      onlyUnread: false,
    ));
  }

  void toggleOnlyUnread() {
    emit(state.copyWith(onlyUnread: !state.onlyUnread));
  }

  void _persistCache(List<NotificationItemEntity> items) {
    try {
      final localStore = _localStorageService ??
          (locator.isRegistered<LocalStorageService>()
              ? locator<LocalStorageService>()
              : null);
      if (localStore != null) {
        final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
        unawaited(localStore.savePreference(key: _cacheKey, data: encoded));
      }
    } on Object catch (_) {}
  }

  @override
  Future<void> close() async {
    await _messageSubscription?.cancel();
    return super.close();
  }
}
