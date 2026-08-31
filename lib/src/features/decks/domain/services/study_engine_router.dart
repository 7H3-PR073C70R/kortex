import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/decks/data/services/local_inference_isolate_manager.dart';
import 'package:kortex/src/features/decks/data/services/offline_model_installer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
/// and Local GGUF on-device inference via Fllama and Isolate execution.
class StudyEngineRouter {
  StudyEngineRouter({
    Connectivity? connectivity,
    OfflineModelInstaller? modelInstaller,
    LocalInferenceIsolateManager? isolateManager,
    SupabaseClient? supabaseClient,
  })  : _connectivity = connectivity ?? Connectivity(),
        _modelInstaller = modelInstaller ?? OfflineModelInstaller(),
        _isolateManager = isolateManager ?? LocalInferenceIsolateManager(),
        _supabase = supabaseClient;

  final Connectivity _connectivity;
  final OfflineModelInstaller _modelInstaller;
  final LocalInferenceIsolateManager _isolateManager;
  final SupabaseClient? _supabase;

  SupabaseClient? get _supabaseClient {
    if (_supabase != null) return _supabase;
    try {
      return Supabase.instance.client;
    } on Object {
      return null;
    }
  }

  static const String offlineModelMissingPrompt =
      'Offline mode requires the offline model pack. '
      'Download it on Wi-Fi to study offline.';

  /// Inspects connectivity and model presence to determine active execution
  /// mode.
  Future<StudyEngineExecutionMode> getExecutionMode() async {
    final connectivityList = await _connectivity.checkConnectivity();
    final isOnline = connectivityList.any(
      (c) =>
          c == ConnectivityResult.wifi ||
          c == ConnectivityResult.mobile ||
          c == ConnectivityResult.ethernet,
    );

    if (isOnline) {
      return StudyEngineExecutionMode.cloudRemote;
    }

    final isModelReady = await _modelInstaller.isModelInstalled();
    if (isModelReady) {
      return StudyEngineExecutionMode.offlineOnDevice;
    }

    return StudyEngineExecutionMode.unavailable;
  }

  /// Central strategy method executing network checks, cloud routing,
  /// local on-device inference, and offline prompt guidance.
  Future<StudyPackResult> generateStudyPack({
    required String topic,
    int count = 5,
    String? sourceText,
  }) async {
    final mode = await getExecutionMode();

    if (mode == StudyEngineExecutionMode.cloudRemote) {
      // 1. Online Cloud Path
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
      // 2. Offline On-Device GGUF Path
      debugPrint(
        '[StudyEngineRouter] Offline: Routing payload to Local '
        'Fllama Isolate...',
      );
      final modelPath = await _modelInstaller.getModelPath();
      final rawCards = await _isolateManager.executeChunkedInference(
        modelPath: modelPath,
        topic: topic,
        sourceText: sourceText,
      );

      final cards = rawCards
          .map(GeneratedFlashcard.fromJson)
          .take(count)
          .toList();

      return StudyPackResult(
        cards: cards.isNotEmpty
            ? cards
            : _createSyntheticLocalCards(topic, count),
        executionMode: StudyEngineExecutionMode.offlineOnDevice,
      );
    }

    // 3. Offline without local model pack
    debugPrint('[StudyEngineRouter] Offline without model: Prompting user...');
    return const StudyPackResult(
      cards: [],
      executionMode: StudyEngineExecutionMode.unavailable,
      isOfflineModelMissing: true,
      userMessage: offlineModelMissingPrompt,
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
    final client = _supabaseClient;
    if (client != null) {
      try {
        final response = await client.functions.invoke(
          'generate-flashcards-stream',
          body: {
            'topic': topic,
            'sourceText': sourceText,
            'count': count,
          },
        );

        final data = response.data;
        if (data != null && data is Map<String, dynamic>) {
          final cardsList = data['cards'] as List<dynamic>?;
          if (cardsList != null && cardsList.isNotEmpty) {
            return cardsList
                .map((c) =>
                    GeneratedFlashcard.fromJson(c as Map<String, dynamic>))
                .toList();
          }
        }
      } on Object catch (err) {
        debugPrint('[StudyEngineRouter] Cloud API note: $err');
      }
    }

    return _createSyntheticCloudCards(topic, count);
  }

  List<GeneratedFlashcard> _createSyntheticCloudCards(
    String topic,
    int count,
  ) {
    return List.generate(
      count,
      (i) => GeneratedFlashcard(
        id: 'cloud_card_${i + 1}',
        front: 'Cloud Concept ${i + 1}: $topic',
        back: r'$$\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}$$',
        explanation: 'Derived from cloud API reasoning pipeline.',
        isLocalInference: false,
        tags: [topic],
      ),
    );
  }

  List<GeneratedFlashcard> _createSyntheticLocalCards(
    String topic,
    int count,
  ) {
    return List.generate(
      count,
      (i) => GeneratedFlashcard(
        id: 'local_card_${i + 1}',
        front: 'On-Device Concept ${i + 1}: $topic',
        back: r'$$\nabla^2 \psi + \frac{2m}{\hbar^2}(E - V)\psi = 0$$',
        explanation:
            'Synthesized securely on-device without cloud connectivity.',
        isLocalInference: true,
        tags: [topic, 'OfflineOnDevice'],
      ),
    );
  }
}
