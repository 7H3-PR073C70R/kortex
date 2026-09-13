import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/offline_ai/offline_ai.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';

enum StudyEngineExecutionMode {
  cloudRemote,
  offlineOnDevice,
  unavailable,
}

class GeneratedFlashcard {
  const GeneratedFlashcard({
    required this.id,
    required this.front,
    required this.back,
    required this.explanation,
    required this.isLocalInference,
    this.tags = const [],
  });

  factory GeneratedFlashcard.fromJson(Map<String, dynamic> json) {
    final defaultId = 'card_${DateTime.now().millisecondsSinceEpoch}';
    return GeneratedFlashcard(
      id: json['id'] as String? ?? defaultId,
      front: json['front'] as String? ?? '',
      back: json['back'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      isLocalInference: json['isLocalInference'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  final String id;
  final String front;
  final String back;
  final String explanation;
  final bool isLocalInference;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
    'id': id,
    'front': front,
    'back': back,
    'explanation': explanation,
    'isLocalInference': isLocalInference,
    'tags': tags,
  };
}

class StudyPackResult {
  const StudyPackResult({
    required this.cards,
    required this.executionMode,
    this.isOfflineModelMissing = false,
    this.userMessage,
  });

  final List<GeneratedFlashcard> cards;
  final StudyEngineExecutionMode executionMode;
  final bool isOfflineModelMissing;
  final String? userMessage;
}

/// Network-aware router selecting between Cloud Streaming endpoints
/// and Local pre-indexed on-device engine.
class StudyEngineRouter {
  StudyEngineRouter({
    Connectivity? connectivity,
    LocalInferenceIsolateManager? isolateManager,
    ExperimentalOfflineGuard? offlineGuard,
    Dio? dio,
    SubscriptionGuard? subscriptionGuard,
  }) : _connectivity = connectivity ?? Connectivity(),
       _isolateManager = isolateManager ?? LocalInferenceIsolateManager(),
       _offlineGuard = offlineGuard ??
           ExperimentalOfflineGuard(connectivity: connectivity),
       _dio = dio ?? Dio(),
       _subscriptionGuard = subscriptionGuard;

  final Connectivity _connectivity;
  final LocalInferenceIsolateManager _isolateManager;
  final ExperimentalOfflineGuard _offlineGuard;
  final Dio _dio;
  final SubscriptionGuard? _subscriptionGuard;

  /// The active isolate manager instance.
  LocalInferenceIsolateManager get isolateManager => _isolateManager;

  /// The active offline guard instance.
  ExperimentalOfflineGuard get offlineGuard => _offlineGuard;

  static const String offlineModelMissingPrompt =
      'Offline mode ready. Generated instantly on-device without data usage.';

  static const String cloudAiRequiresProPrompt =
      'Cloud AI synthesis requires Kortexify Pro. '
      'Using free instant on-device flashcard generation, or upgrade to Pro for cloud AI.';

  /// Inspects connectivity and subscription to determine active execution mode.
  Future<StudyEngineExecutionMode> getExecutionMode({bool? isPro}) async {
    final connectivityList = await _connectivity.checkConnectivity();
    final isOnline = connectivityList.any(
      (c) =>
          c == ConnectivityResult.wifi ||
          c == ConnectivityResult.mobile ||
          c == ConnectivityResult.ethernet,
    );

    final bool userHasPro;
    if (isPro != null) {
      userHasPro = isPro;
    } else if (_subscriptionGuard != null) {
      userHasPro = _subscriptionGuard.canAccessCloudAi();
    } else if (locator.isRegistered<SubscriptionGuard>()) {
      userHasPro = locator<SubscriptionGuard>().canAccessCloudAi();
    } else {
      userHasPro = true;
    }

    if (isOnline && userHasPro) {
      return StudyEngineExecutionMode.cloudRemote;
    }

    return StudyEngineExecutionMode.offlineOnDevice;
  }

  /// Central strategy method executing network checks, cloud routing,
  /// and instant on-device inference.
  Future<StudyPackResult> generateStudyPack({
    required String topic,
    int count = 5,
    String? sourceText,
    bool forceOffline = false,
  }) async {
    final mode = forceOffline
        ? StudyEngineExecutionMode.offlineOnDevice
        : await getExecutionMode();

    if (mode == StudyEngineExecutionMode.cloudRemote) {
      debugPrint('[StudyEngineRouter] Online: Routing payload to Cloud API...');
      try {
        final cards = await _fetchFromCloud(
          topic: topic,
          count: count,
          sourceText: sourceText,
        );
        if (cards.isEmpty) {
          return const StudyPackResult(
            cards: [],
            executionMode: StudyEngineExecutionMode.unavailable,
            userMessage:
                'AI engine could not generate cards for this topic. Please provide more source text or try a different topic.',
          );
        }
        return StudyPackResult(
          cards: cards,
          executionMode: StudyEngineExecutionMode.cloudRemote,
        );
      } on Object catch (err) {
        debugPrint('[StudyEngineRouter] Cloud API error: $err');
        return StudyPackResult(
          cards: [],
          executionMode: StudyEngineExecutionMode.unavailable,
          userMessage:
              'Cloud AI generation failed ($err). Please check your internet connection and try again.',
        );
      }
    }

    if (mode == StudyEngineExecutionMode.offlineOnDevice) {
      debugPrint('[StudyEngineRouter] Offline: Checking on-device model availability...');
      final sharedModelPath = await LocalLlmEngineClient.findSharedModelPath();
      if (sharedModelPath == null) {
        return const StudyPackResult(
          cards: [],
          executionMode: StudyEngineExecutionMode.unavailable,
          isOfflineModelMissing: true,
          userMessage:
              'On-device AI model weights are not downloaded. Please download the 248MB offline model from Settings or connect to the internet.',
        );
      }

      try {
        final rawCards = await _isolateManager.executeChunkedInference(
          modelPath: sharedModelPath,
          topic: topic,
          sourceText: sourceText,
        );
        final cards = rawCards.map(GeneratedFlashcard.fromJson).toList();
        return StudyPackResult(
          cards: cards,
          executionMode: StudyEngineExecutionMode.offlineOnDevice,
        );
      } on Object catch (err) {
        return StudyPackResult(
          cards: [],
          executionMode: StudyEngineExecutionMode.unavailable,
          userMessage: 'On-device AI synthesis failed ($err).',
        );
      }
    }

    debugPrint('[StudyEngineRouter] Engine unavailable: Prompting user...');
    final connectivityList = await _connectivity.checkConnectivity();
    final isOnline = connectivityList.any(
      (c) =>
          c == ConnectivityResult.wifi ||
          c == ConnectivityResult.mobile ||
          c == ConnectivityResult.ethernet,
    );
    final userMessage = isOnline
        ? cloudAiRequiresProPrompt
        : offlineModelMissingPrompt;

    return StudyPackResult(
      cards: [],
      executionMode: StudyEngineExecutionMode.unavailable,
      isOfflineModelMissing: true,
      userMessage: userMessage,
    );
  }

  /// Directly processes asset content (such as deck flashcards, OCR text, or document content)
  /// and generates structured study items using either Cloud AI or on-device local GGUF inference
  /// depending on network connectivity and offline model presence.
  Future<StudyPackResult> processDirectAsset({
    required String assetId,
    required String content,
    String? topic,
    int count = 10,
  }) async {
    return generateStudyPack(
      topic: topic ?? 'Asset $assetId',
      count: count,
      sourceText: content,
    );
  }

  /// Streams flashcard generations, routing dynamically to Cloud or Local LLM.
  Stream<GeneratedFlashcard> generateFlashcards({
    required String topic,
    required int count,
    String? sourceText,
  }) async* {
    final result = await generateStudyPack(
      topic: topic,
      count: count,
      sourceText: sourceText,
    );

    if (result.cards.isEmpty) {
      throw StateError(result.userMessage ?? 'No flashcards generated');
    }

    for (final card in result.cards) {
      yield card;
    }
  }

  Future<List<GeneratedFlashcard>> _fetchFromCloud({
    required String topic,
    required int count,
    String? sourceText,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${AppApiEndpoint.baseUri}/functions/v1/generate-flashcards-stream',
      data: {
        'topic': topic,
        'sourceText': sourceText,
        'count': count,
      },
      options: Options(
        headers: {
          'apikey': AppEnv.apiKey,
          'Authorization': 'Bearer ${AppEnv.apiKey}',
        },
      ),
    );

    final data = response.data;
    if (data != null) {
      final cardsList = data['cards'] as List<dynamic>?;
      if (cardsList != null && cardsList.isNotEmpty) {
        return cardsList
            .map(
              (c) => GeneratedFlashcard.fromJson(c as Map<String, dynamic>),
            )
            .toList();
      }
    }

    return const [];
  }
}
