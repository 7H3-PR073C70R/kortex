import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_llama/src/services/huggingface_downloader.dart';

void main() {
  test('download GGUF model test', () async {
    final downloader = HuggingFaceDownloader();
    print('Testing downloadGGUFModel...');
    try {
      final path = await downloader.downloadGGUFModel(
        modelId: 'Segilmez06/SmolLM2-135M-Instruct-Q4_K_M-GGUF',
        onProgress: (p) {
          print('Progress: ${(p.progress * 100).toStringAsFixed(1)}% - ${p.status}');
        },
      );
      print('DOWNLOAD SUCCESS! Path: $path');
    } catch (e, st) {
      print('DOWNLOAD ERROR: $e\n$st');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
