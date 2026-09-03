import 'model_source.dart';

/// Информация о предустановленной модели
class PresetModel {
  final String id;
  final String name;
  final String description;
  final ModelSource source;
  final String? variant; // Для Ollama (q2_k, q4_k_s и т.д.)
  final List<String> files;
  final List<String> languages;
  final String size;
  final int? contextSize;
  final Map<String, dynamic>? metadata;
  
  const PresetModel({
    required this.id,
    required this.name,
    required this.description,
    required this.source,
    this.variant,
    this.files = const [],
    this.languages = const [],
    required this.size,
    this.contextSize,
    this.metadata,
  });
  
  /// Полное имя модели с вариантом
  String get fullName {
    if (variant != null) {
      return '$id:$variant';
    }
    return id;
  }
  
  /// Копирование с изменениями
  PresetModel copyWith({
    String? id,
    String? name,
    String? description,
    ModelSource? source,
    String? variant,
    List<String>? files,
    List<String>? languages,
    String? size,
    int? contextSize,
    Map<String, dynamic>? metadata,
  }) {
    return PresetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      source: source ?? this.source,
      variant: variant ?? this.variant,
      files: files ?? this.files,
      languages: languages ?? this.languages,
      size: size ?? this.size,
      contextSize: contextSize ?? this.contextSize,
      metadata: metadata ?? this.metadata,
    );
  }
  
  @override
  String toString() {
    return 'PresetModel($fullName, source: ${source.displayName}, size: $size)';
  }
}

/// Список предустановленных моделей
class PresetModels {
  // HuggingFace GGUF models for on-device inference
  static const smolLM2Q4K = PresetModel(
    id: 'Segilmez06/SmolLM2-135M-Instruct-Q4_K_M-GGUF',
    name: 'SmolLM2 135M Instruct (Q4_K_M)',
    description: '⭐ Highly optimized on-device GGUF model for mobile and edge devices',
    source: ModelSource.huggingFace,
    files: ['smollm2-135m-instruct-q4_k_m.gguf'],
    languages: ['🇬🇧 English'],
    size: '100 MB',
    contextSize: 2048,
    metadata: {
      'recommended': true,
      'speed': 'fastest',
    },
  );

  static const qwen25Q4K = PresetModel(
    id: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
    name: 'Qwen 2.5 0.5B Instruct (Q4_K_M)',
    description: 'High performance small language model with rich reasoning',
    source: ModelSource.huggingFace,
    files: ['qwen2.5-0.5b-instruct-q4_k_m.gguf'],
    languages: ['🇬🇧 English'],
    size: '350 MB',
    contextSize: 2048,
    metadata: {
      'recommended': false,
      'speed': 'fast',
    },
  );

  static const shridharMultimodal = PresetModel(
    id: 'nativemind/shridhar_8k_multimodal',
    name: 'Shridhar 8K Multimodal',
    description: 'Мультимодальная духовная модель с поддержкой 4 языков',
    source: ModelSource.huggingFace,
    files: [
      'adapter_model.safetensors',
      'adapter_config.json',
    ],
    languages: ['🇷🇺 Русский', '🇪🇸 Испанский', '🇮🇳 Хинди', '🇹🇭 Тайский'],
    size: '~50 MB',
    contextSize: 8192,
  );
  
  // Ollama модели - Braindler
  static const braindlerQ2K = PresetModel(
    id: 'nativemind/braindler',
    name: 'Braindler Q2_K',
    description: 'Самая быстрая версия, оптимальна для мобильных устройств',
    source: ModelSource.ollama,
    variant: 'q2_k',
    files: [],
    languages: ['🇬🇧 English'],
    size: '72 MB',
    contextSize: 2048,
    metadata: {
      'recommended': false,
      'speed': 'fastest',
    },
  );
  
  static const braindlerQ4K = PresetModel(
    id: 'nativemind/braindler',
    name: 'Braindler Q4_K',
    description: '⭐ Рекомендуется - оптимальный баланс скорости и качества',
    source: ModelSource.ollama,
    variant: 'q4_k_s',
    files: [],
    languages: ['🇬🇧 English'],
    size: '88 MB',
    contextSize: 2048,
    metadata: {
      'recommended': true,
      'speed': 'fast',
    },
  );
  
  static const braindlerQ5K = PresetModel(
    id: 'nativemind/braindler',
    name: 'Braindler Q5_K',
    description: 'Повышенное качество, немного медленнее',
    source: ModelSource.ollama,
    variant: 'q5_k_m',
    files: [],
    languages: ['🇬🇧 English'],
    size: '103 MB',
    contextSize: 2048,
    metadata: {
      'recommended': false,
      'speed': 'medium',
    },
  );
  
  static const braindlerQ8 = PresetModel(
    id: 'nativemind/braindler',
    name: 'Braindler Q8',
    description: 'Высокое качество для мощных устройств',
    source: ModelSource.ollama,
    variant: 'q8_0',
    files: [],
    languages: ['🇬🇧 English'],
    size: '140 MB',
    contextSize: 2048,
    metadata: {
      'recommended': false,
      'speed': 'slow',
    },
  );
  
  static const braindlerF16 = PresetModel(
    id: 'nativemind/braindler',
    name: 'Braindler F16',
    description: 'Максимальное качество, требует много ресурсов',
    source: ModelSource.ollama,
    variant: 'f16',
    files: [],
    languages: ['🇬🇧 English'],
    size: '256 MB',
    contextSize: 2048,
    metadata: {
      'recommended': false,
      'speed': 'very_slow',
    },
  );
  
  /// Все предустановленные модели
  static const List<PresetModel> all = [
    smolLM2Q4K,
    qwen25Q4K,
    shridharMultimodal,
    braindlerQ2K,
    braindlerQ4K,
    braindlerQ5K,
    braindlerQ8,
    braindlerF16,
  ];
  
  /// Получить модели по источнику
  static List<PresetModel> bySource(ModelSource source) {
    return all.where((model) => model.source == source).toList();
  }
  
  /// Получить рекомендуемые модели
  static List<PresetModel> get recommended {
    return all.where((model) {
      final isRecommended = model.metadata?['recommended'] as bool?;
      return isRecommended == true;
    }).toList();
  }
  
  /// Найти модель по ID
  static PresetModel? findById(String id, {String? variant}) {
    return all.firstWhere(
      (model) {
        if (variant != null) {
          return model.id == id && model.variant == variant;
        }
        return model.id == id;
      },
      orElse: () => all.first, // fallback
    );
  }
}


