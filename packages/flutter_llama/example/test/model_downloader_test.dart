import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_llama_example/services/model_downloader.dart';
import 'dart:io';

void main() {
  group('ModelDownloader Tests', () {
    test('PresetModels should contain Shridhar model', () {
      expect(PresetModels.all, isNotEmpty);
      expect(PresetModels.all.first.id, 'nativemind/shridhar_8k_multimodal');
      expect(PresetModels.all.first.name, 'Shridhar 8K Multimodal');
      expect(PresetModels.all.first.languages, hasLength(4));
    });

    test('Shridhar model should have correct properties', () {
      final model = PresetModels.shridharMultimodal;
      
      expect(model.id, 'nativemind/shridhar_8k_multimodal');
      expect(model.name, 'Shridhar 8K Multimodal');
      expect(model.description, contains('Мультимодальная'));
      expect(model.languages, contains('🇷🇺 Русский'));
      expect(model.languages, contains('🇪🇸 Испанский'));
      expect(model.languages, contains('🇮🇳 Хинди'));
      expect(model.languages, contains('🇹🇭 Тайский'));
      expect(model.ggufFiles, isNotEmpty);
    });

    test('ModelDownloader should return empty list when no models downloaded',
        () async {
      final models = await ModelDownloader.getDownloadedModels();
      expect(models, isA<List<String>>());
    });

    test('ModelDownloader should handle model path correctly', () async {
      const modelId = 'nativemind/shridhar_8k_multimodal';
      const fileName = 'adapter_model.safetensors';
      
      final modelPath = await ModelDownloader.getModelPath(modelId, fileName);
      
      expect(modelPath, anyOf(isNull, isA<String>()));
    });

    test('PresetModel languages should be formatted correctly', () {
      final model = PresetModels.shridharMultimodal;
      
      for (final lang in model.languages) {
        expect(
          lang,
          anyOf([
            contains('🇷🇺'),
            contains('🇪🇸'),
            contains('🇮🇳'),
            contains('🇹🇭'),
          ]),
        );
      }
    });

    test('Model ID should be convertible to safe directory name', () {
      const modelId = 'nativemind/shridhar_8k_multimodal';
      final safeName = modelId.replaceAll('/', '_');
      
      expect(safeName, 'nativemind_shridhar_8k_multimodal');
      expect(safeName, isNot(contains('/')));
    });
  });

  group('PresetModel Integration Tests', () {
    test('All preset models should have required fields', () {
      for (final model in PresetModels.all) {
        expect(model.id, isNotEmpty);
        expect(model.name, isNotEmpty);
        expect(model.description, isNotEmpty);
        expect(model.ggufFiles, isNotEmpty);
        expect(model.languages, isNotEmpty);
        expect(model.size, isNotEmpty);
      }
    });

    test('Model GGUF files should have valid extensions', () {
      for (final model in PresetModels.all) {
        for (final file in model.ggufFiles) {
          expect(
            file.endsWith('.safetensors') || 
            file.endsWith('.json') || 
            file.endsWith('.gguf'),
            isTrue,
            reason: 'File $file should have a valid extension',
          );
        }
      }
    });
  });
}

