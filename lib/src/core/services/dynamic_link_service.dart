import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/app/router/app_router.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_room_entity.dart';

/// Supported types of dynamic links within Kortex.
enum DynamicLinkType {
  deck('deck'),
  forum('forum'),
  quizDuel('quiz_duel'),
  studyRoom('study_room'),
  promo('promo'),
  course('course'),
  unknown('unknown')
  ;

  const DynamicLinkType(this.value);
  final String value;

  static DynamicLinkType fromString(String raw) {
    final clean = raw.trim().toLowerCase().replaceAll('-', '_');
    return DynamicLinkType.values.firstWhere(
      (e) => e.value == clean || e.name.toLowerCase() == clean,
      orElse: () => DynamicLinkType.unknown,
    );
  }
}

/// Structured payload parsed from a deep link or Firebase Dynamic Link.
class DynamicLinkPayload {
  const DynamicLinkPayload({
    required this.type,
    required this.targetId,
    this.parameters = const {},
    this.title,
    this.description,
    this.imageUrl,
    this.originalUri,
  });

  final DynamicLinkType type;
  final String targetId;
  final Map<String, String> parameters;
  final String? title;
  final String? description;
  final String? imageUrl;
  final Uri? originalUri;

  @override
  String toString() =>
      'DynamicLinkPayload(type: ${type.value}, targetId: $targetId, params: $parameters)';
}

/// Centralized service handling Firebase Dynamic Links, custom URL schemes,
/// deep link generation, parsing, and automated route navigation.
class DynamicLinkService {
  DynamicLinkService({
    String? defaultHost,
    String? customScheme,
  })  : _defaultHost = defaultHost ?? 'kortex-study-app-2026.web.app',
        _customScheme = customScheme ?? 'kortex';

  final String _defaultHost;
  final String _customScheme;

  final StreamController<DynamicLinkPayload> _linkStreamController =
      StreamController<DynamicLinkPayload>.broadcast();

  /// Stream of incoming deep/dynamic link payloads.
  Stream<DynamicLinkPayload> get onLinkReceived => _linkStreamController.stream;

  /// Closes stream resources.
  void dispose() {
    unawaited(_linkStreamController.close());
  }

  /// Manually triggers processing of an incoming raw URI string or Uri object.
  void handleRawUri(Uri uri) {
    final payload = parseUri(uri);
    if (payload != null && payload.type != DynamicLinkType.unknown) {
      _linkStreamController.add(payload);
    }
  }

  /// Builds a canonical, cross-platform dynamic link URL.
  /// Uses Firebase Hosting `/share` route format which fallbacks to custom app scheme
  /// or web preview landing page.
  Uri generateDynamicLink({
    required DynamicLinkType type,
    required String targetId,
    Map<String, String>? parameters,
    String? title,
    String? description,
    String? imageUrl,
  }) {
    final queryParams = <String, String>{
      'type': type.value,
      'id': targetId,
      'apn': 'com.kortexify.app',
      'ibi': 'com.kortexify.app',
    };

    if (parameters != null && parameters.isNotEmpty) {
      parameters.forEach((key, val) {
        if (!queryParams.containsKey(key)) {
          queryParams[key] = val;
        }
      });
    }

    if (title != null && title.isNotEmpty) queryParams['title'] = title;
    if (description != null && description.isNotEmpty) {
      queryParams['desc'] = description;
    }
    if (imageUrl != null && imageUrl.isNotEmpty) {
      queryParams['img'] = imageUrl;
    }

    return Uri.https(_defaultHost, '/share', queryParams);
  }

  /// Builds a lightweight custom scheme deep-link URL (e.g. `kortex://share?type=deck&id=123`).
  Uri generateCustomSchemeLink({
    required DynamicLinkType type,
    required String targetId,
    Map<String, String>? parameters,
  }) {
    final queryParams = <String, String>{
      'type': type.value,
      'id': targetId,
    };
    if (parameters != null) queryParams.addAll(parameters);

    return Uri(
      scheme: _customScheme,
      host: 'share',
      queryParameters: queryParams,
    );
  }

  /// Parses an incoming [Uri] (HTTPS web link or custom scheme link) into a [DynamicLinkPayload].
  DynamicLinkPayload? parseUri(Uri uri) {
    try {
      // 1. Check custom scheme: kortex://share?type=deck&id=xxx or kortex://deck/xxx
      if (uri.scheme == _customScheme || uri.scheme == 'com.kortexify.app') {
        if (uri.host == 'share' || uri.path.contains('share')) {
          final typeStr = uri.queryParameters['type'] ?? '';
          final targetId = uri.queryParameters['id'] ?? uri.queryParameters['targetId'] ?? '';
          final type = DynamicLinkType.fromString(typeStr);
          return DynamicLinkPayload(
            type: type,
            targetId: targetId,
            parameters: uri.queryParameters,
            originalUri: uri,
          );
        }

        final hostType = DynamicLinkType.fromString(uri.host);
        if (hostType != DynamicLinkType.unknown) {
          final targetId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
          return DynamicLinkPayload(
            type: hostType,
            targetId: targetId,
            parameters: uri.queryParameters,
            originalUri: uri,
          );
        }

        // Path based custom scheme: kortex://app/deck/123 or kortex://app/forum/456
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          final type = DynamicLinkType.fromString(segments.first);
          final targetId = segments.length > 1 ? segments[1] : '';
          return DynamicLinkPayload(
            type: type,
            targetId: targetId,
            parameters: uri.queryParameters,
            originalUri: uri,
          );
        }
      }

      // 2. Check Firebase / Web URL: https://kortex-study-app-2026.web.app/share?type=...&id=...
      final typeStr = uri.queryParameters['type'] ?? '';
      final targetId = uri.queryParameters['id'] ??
          uri.queryParameters['targetId'] ??
          uri.queryParameters['deckId'] ??
          uri.queryParameters['deck_id'] ??
          uri.queryParameters['postId'] ??
          uri.queryParameters['post_id'] ??
          uri.queryParameters['roomId'] ??
          uri.queryParameters['room_id'] ??
          uri.queryParameters['code'] ??
          '';

      if (typeStr.isNotEmpty) {
        final type = DynamicLinkType.fromString(typeStr);
        if (type != DynamicLinkType.unknown &&
            (targetId.isNotEmpty || type == DynamicLinkType.promo)) {
          return DynamicLinkPayload(
            type: type,
            targetId: targetId.isNotEmpty ? targetId : 'promo',
            parameters: uri.queryParameters,
            title: uri.queryParameters['title'],
            description: uri.queryParameters['desc'] ??
                uri.queryParameters['description'],
            imageUrl: uri.queryParameters['img'],
            originalUri: uri,
          );
        }
      }

      // 3. Fallback path parsing for web links: https://domain/deck/123 or https://domain/forum/456
      final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (pathSegments.length >= 2) {
        final typeStrCandidate = pathSegments[0];
        final idCandidate = pathSegments[1];
        final type = DynamicLinkType.fromString(typeStrCandidate);
        if (type != DynamicLinkType.unknown) {
          return DynamicLinkPayload(
            type: type,
            targetId: idCandidate,
            parameters: uri.queryParameters,
            originalUri: uri,
          );
        }
      }

      return null;
    } on Object catch (e) {
      debugPrint('[DynamicLinkService] Error parsing URI ($uri): $e');
      return null;
    }
  }

  /// Resolves the corresponding [PageRouteInfo] for a given [DynamicLinkPayload].
  PageRouteInfo? routeForPayload(DynamicLinkPayload payload) {
    switch (payload.type) {
      case DynamicLinkType.deck:
        if (payload.targetId.isNotEmpty) {
          final isStudy = payload.parameters['mode'] == 'study';
          if (isStudy) {
            return StudySessionRoute(deckId: payload.targetId);
          } else {
            return DeckDetailRoute(deckId: payload.targetId);
          }
        }
        return const DecksRoute();

      case DynamicLinkType.forum:
        if (payload.targetId.isNotEmpty) {
          final post = ForumPostEntity(
            id: payload.targetId,
            title: payload.title ?? 'Shared Discussion',
            content: payload.description ?? '',
            authorId: payload.parameters['authorId'] ?? 'user-anonymous',
            authorName: payload.parameters['authorName'] ?? 'Kortex Scholar',
            track: payload.parameters['track'] ?? 'General',
            createdAt: DateTime.now(),
          );
          return ForumThreadDetailRoute(
            post: post,
            highlightReplyId: payload.parameters['replyId'] ??
                payload.parameters['reply_id'],
          );
        }
        return const CommunityHubRoute();

      case DynamicLinkType.quizDuel:
        final deckId = payload.parameters['deckId'] ??
            payload.parameters['deck_id'] ??
            (payload.targetId.isNotEmpty ? payload.targetId : 'deck-default');
        return QuizWorkspaceRoute(deckId: deckId);

      case DynamicLinkType.studyRoom:
        if (payload.targetId.isNotEmpty) {
          final room = StudyRoomEntity(
            id: payload.targetId,
            title: payload.title ?? 'Live Study Room',
            subject: payload.description ?? 'Academic Co-Working',
            createdBy: payload.parameters['hostId'] ?? 'host-user',
          );
          return LiveStudyRoomRoute(room: room);
        }
        return const StudyHubRoute();

      case DynamicLinkType.promo:
        return PaywallRoute();

      case DynamicLinkType.course:
        if (payload.targetId.isNotEmpty) {
          return CourseModuleRoute(
            courseId: payload.targetId,
            courseCode: payload.parameters['code'] ?? 'COURSE',
            courseTitle: payload.title ?? 'Academic Course',
          );
        }
        return CurateCoursesRoute();

      case DynamicLinkType.unknown:
        return null;
    }
  }

  /// Navigates to the corresponding screen inside [AppRouter] based on [DynamicLinkPayload].
  Future<bool> handlePayload({
    required DynamicLinkPayload payload,
    required AppRouter appRouter,
  }) async {
    debugPrint('[DynamicLinkService] Handling link payload: $payload');
    try {
      final route = routeForPayload(payload);
      if (route != null) {
        await appRouter.push(route);
        return true;
      }
      return false;
    } on Object catch (e) {
      debugPrint('[DynamicLinkService] Navigation error for payload ($payload): $e');
      return false;
    }
  }
}
