import 'package:flutter_llama/flutter_llama.dart';
import '../utils/model_downloader.dart';

/// Демонстрация работы с генерацией текста
/// Запустите: dart run example/lib/demo/test_generation_demo.dart
void main() async {
  print('╔════════════════════════════════════════════════════╗');
  print('║   Flutter Llama - Демонстрация генерации текста   ║');
  print('╚════════════════════════════════════════════════════╝\n');

  try {
    print('📦 Шаг 1: Проверка модели...');
    String? modelPath = await ModelDownloader.getModelPath('braindler-q2_k');

    if (modelPath == null) {
      print('⬇️  Модель не найдена, начинается загрузка...');
      print('   (Размер: 72 MB, это может занять время)\n');

      modelPath = await ModelDownloader.downloadModel(
        'braindler-q2_k',
        onProgress: (progress) {
          final percent = (progress * 100).toStringAsFixed(1);
          final bar = '█' * (progress * 40).toInt();
          final empty = '░' * (40 - (progress * 40).toInt());
          print('\r   [$bar$empty] $percent%');
        },
      );
      print('\n✅ Модель загружена!\n');
    } else {
      print('✅ Модель найдена: $modelPath\n');
    }

    print('🔧 Шаг 2: Инициализация FlutterLlama...');
    final llama = FlutterLlama.instance;

    final config = LlamaConfig(
      modelPath: modelPath,
      nThreads: 4,
      contextSize: 2048,
      useGpu: true,
      verbose: false,
    );

    final loaded = await llama.loadModel(config);
    if (!loaded) {
      print('❌ Не удалось загрузить модель');
      return;
    }
    print('✅ Модель инициализирована\n');

    final info = await llama.getModelInfo();
    if (info != null) {
      print('ℹ️  Информация о модели:');
      info.forEach((key, value) {
        print('   $key: $value');
      });
      print('');
    }

    print('═══════════════════════════════════════════════════');
    print('🎭 ДЕМОНСТРАЦИЯ ГЕНЕРАЦИИ');
    print('═══════════════════════════════════════════════════\n');

    await _testGeneration(
      llama,
      prompt: 'Харе Кришна Харе Кришна',
      description: 'Махамантра',
      maxTokens: 50,
    );

    print('\n' + '─' * 50 + '\n');

    await _testGeneration(
      llama,
      prompt: 'Что такое искусственный интеллект?',
      description: 'Вопрос об ИИ',
      maxTokens: 100,
    );

    print('\n' + '─' * 50 + '\n');

    await _testGeneration(
      llama,
      prompt: 'Напиши короткое стихотворение о природе',
      description: 'Творческая задача',
      maxTokens: 80,
    );

    print('\n═══════════════════════════════════════════════════');
    print('🌊 ДЕМОНСТРАЦИЯ STREAMING');
    print('═══════════════════════════════════════════════════\n');

    try {
      print('📝 Промпт: "Расскажи короткую историю"\n');
      print('🔄 Генерация (streaming):\n');

      final streamParams = GenerationParams(
        prompt: 'Расскажи короткую историю',
        maxTokens: 60,
        temperature: 0.8,
      );

      final tokens = <String>[];
      final stopwatch = Stopwatch()..start();

      await for (final token in llama.generateStream(streamParams)) {
        tokens.add(token);
        print(token); // Выводим токен сразу
      }

      stopwatch.stop();

      print('\n\n📊 Статистика:');
      print('   Токенов: ${tokens.length}');
      print('   Время: ${stopwatch.elapsedMilliseconds}ms');
      print(
        '   Скорость: ${(tokens.length / stopwatch.elapsedMilliseconds * 1000).toStringAsFixed(2)} tok/s',
      );
    } catch (e) {
      print('⚠️  Streaming не поддерживается или не реализован: $e');
    }

    print('\n═══════════════════════════════════════════════════');
    print('🧹 Завершение работы...');
    await llama.unloadModel();
    print('✅ Модель выгружена');

    print('\n╔════════════════════════════════════════════════════╗');
    print('║              ДЕМОНСТРАЦИЯ ЗАВЕРШЕНА               ║');
    print('╚════════════════════════════════════════════════════╝');
  } catch (e, stackTrace) {
    print('\n❌ Ошибка: $e');
    print('Stack trace:\n$stackTrace');
  }
}

Future<void> _testGeneration(
  FlutterLlama llama, {
  required String prompt,
  required String description,
  required int maxTokens,
}) async {
  print('🎯 Тест: $description');
  print('📝 Промпт: "$prompt"');
  print('🔧 Параметры: maxTokens=$maxTokens\n');

  final stopwatch = Stopwatch()..start();

  try {
    final params = GenerationParams(
      prompt: prompt,
      maxTokens: maxTokens,
      temperature: 0.7,
      topP: 0.9,
      topK: 40,
    );

    final response = await llama.generate(params);
    stopwatch.stop();

    print('💬 Ответ:');
    print('┌─────────────────────────────────────────────┐');
    print('│ ${_wrapText(response.text, 43)}');
    print('└─────────────────────────────────────────────┘');

    print('\n📊 Статистика:');
    print('   Токенов сгенерировано: ${response.tokensGenerated}');
    print('   Время генерации: ${response.generationTimeMs}ms');
    print(
      '   Скорость: ${response.tokensPerSecond.toStringAsFixed(2)} tokens/sec',
    );
    print('   Длина текста: ${response.text.length} символов');
  } catch (e) {
    stopwatch.stop();
    print('❌ Ошибка генерации: $e');
    print('   Время до ошибки: ${stopwatch.elapsedMilliseconds}ms');
  }
}

String _wrapText(String text, int width) {
  final lines = <String>[];
  var currentLine = '';

  for (final word in text.split(' ')) {
    if (currentLine.isEmpty) {
      currentLine = word;
    } else if ((currentLine + ' ' + word).length <= width) {
      currentLine += ' ' + word;
    } else {
      lines.add(currentLine);
      currentLine = word;
    }
  }

  if (currentLine.isNotEmpty) {
    lines.add(currentLine);
  }

  return lines.join(' │\n│ ');
}





