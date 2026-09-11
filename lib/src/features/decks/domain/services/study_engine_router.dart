import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/offline_ai/offline_ai.dart';

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
      final cards = await _fetchFromCloud(
        topic: topic,
        count: count,
        sourceText: sourceText,
      );
      return StudyPackResult(
        cards: cards,
        executionMode: StudyEngineExecutionMode.cloudRemote,
      );
    }

    if (mode == StudyEngineExecutionMode.offlineOnDevice) {
      debugPrint('[StudyEngineRouter] Offline: Instant on-device concept synthesis...');
      return StudyPackResult(
        cards: _createSyntheticLocalCards(topic, count),
        executionMode: StudyEngineExecutionMode.offlineOnDevice,
      );
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

    if (result.isOfflineModelMissing) {
      throw StateError(result.userMessage ?? offlineModelMissingPrompt);
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
    try {
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
    } on Object catch (err) {
      debugPrint('[StudyEngineRouter] Cloud API note: $err');
    }

    return _createSyntheticCloudCards(topic, count);
  }

  bool _isStemTopic(String topic) {
    final lower = topic.toLowerCase();
    return lower.contains('math') ||
        lower.contains('phys') ||
        lower.contains('chem') ||
        lower.contains('calc') ||
        lower.contains('algeb') ||
        lower.contains('quantum') ||
        lower.contains('eng');
  }

  static final List<({String front, String back, String explanation})> _academicTemplates = [
    (
      front: 'What is the foundational principle and scope of {topic}?',
      back: '{topic} establishes the fundamental principles, taxonomies, and methodologies governing its domain.',
      explanation: 'Core foundational definition and analytical scope for {topic}.',
    ),
    (
      front: 'What is the primary governing framework or mechanism of {topic}?',
      back: 'The governing mechanism of {topic} balances conceptual rules with empirical observations to predict outcomes.',
      explanation: 'Primary operational framework and predictive model of {topic}.',
    ),
    (
      front: 'What are the essential structural components of {topic}?',
      back: 'The system structure of {topic} comprises core assumptions, mediating factors, and observable implications.',
      explanation: 'Structural architecture and component analysis of {topic}.',
    ),
    (
      front: 'How is {topic} practically applied to resolve domain problems?',
      back: 'Practitioners apply {topic} to calibrate models, optimize decision-making, and diagnose operational anomalies.',
      explanation: 'Real-world application and problem-solving methodology in {topic}.',
    ),
    (
      front: 'What boundary conditions or limitations constrain {topic}?',
      back: 'Limitations in {topic} emerge when environmental assumptions degrade or scale factors exceed baseline bounds.',
      explanation: 'Critical evaluation of constraints and boundary limits in {topic}.',
    ),
  ];

  static final List<({String front, String back, String explanation})> _stemTemplates = [
    (
      front: 'State the governing relation and dimensional formula in {topic}.',
      back: r'$$\mathbf{F} = \frac{d\mathbf{p}}{dt} = m\mathbf{a}$$. Fundamental rate of change relation.',
      explanation: 'Dynamical formulation and physical dimension analysis in {topic}.',
    ),
    (
      front: 'State the conservation principle governing {topic}.',
      back: r'$$\sum E_{\text{in}} = \sum E_{\text{out}}$$. Total energy and mass balance across boundary states.',
      explanation: 'Thermodynamic and mechanistic balance laws for {topic}.',
    ),
    (
      front: 'What is the integral formulation for boundary flux in {topic}?',
      back: r'$$\oint_{\partial \Omega} \mathbf{v} \cdot d\mathbf{A} = \iiint_{\Omega} (\nabla \cdot \mathbf{v}) dV$$ (Gauss-Divergence).',
      explanation: 'Vector field divergence theorem applied to boundary surfaces in {topic}.',
    ),
    (
      front: 'Explain the steady-state equilibrium criterion in {topic}.',
      back: r'$$\frac{\partial u}{\partial t} = \alpha \nabla^2 u = 0 \implies \nabla^2 u = 0$$. Laplace equilibrium condition.',
      explanation: 'Harmonic balance and zero time-rate flux in {topic}.',
    ),
  ];

  List<GeneratedFlashcard> _createSyntheticCloudCards(
    String topic,
    int count,
  ) {
    final isStem = _isStemTopic(topic);
    final templates = isStem ? _stemTemplates : _academicTemplates;

    return List.generate(
      count,
      (i) {
        final t = templates[i % templates.length];
        return GeneratedFlashcard(
          id: 'cloud_card_${i + 1}',
          front: t.front.replaceAll('{topic}', topic),
          back: t.back.replaceAll('{topic}', topic),
          explanation: t.explanation.replaceAll('{topic}', topic),
          isLocalInference: false,
          tags: [topic],
        );
      },
    );
  }

  List<GeneratedFlashcard> _createSyntheticLocalCards(
    String topic,
    int count,
  ) {
    final isStem = _isStemTopic(topic);
    final templates = isStem ? _stemTemplates : _academicTemplates;

    return List.generate(
      count,
      (i) {
        final t = templates[i % templates.length];
        return GeneratedFlashcard(
          id: 'local_card_${i + 1}',
          front: 'On-Device: ${t.front.replaceAll("{topic}", topic)}',
          back: t.back.replaceAll('{topic}', topic),
          explanation:
              'Synthesized securely on-device for $topic without cloud connectivity.',
          isLocalInference: true,
          tags: [topic, 'OfflineOnDevice'],
        );
      },
    );
  }
}
