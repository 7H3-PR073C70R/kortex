import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Helper to load real font binaries during testing so that screenshots
/// have complete, legible typography instead of empty glyphs or Ahem blocks.
class TestFontLoaderHelper {
  static bool _fontsLoaded = false;

  static Future<void> loadFonts() async {
    if (_fontsLoaded) return;

    // Allow GoogleFonts to fall back gracefully to loaded local families
    GoogleFonts.config.allowRuntimeFetching = false;

    // 1. Plus Jakarta Sans
    final pjsFile = File('assets/fonts/PlusJakartaSans.ttf');
    if (await pjsFile.exists()) {
      final bytes = await pjsFile.readAsBytes();
      final byteData = ByteData.view(bytes.buffer);

      final pjsFamilies = [
        'PlusJakartaSans',
        'Plus Jakarta Sans',
        'packages/google_fonts/PlusJakartaSans',
        'packages/google_fonts/PlusJakartaSans_regular',
        'packages/google_fonts/PlusJakartaSans_500',
        'packages/google_fonts/PlusJakartaSans_600',
        'packages/google_fonts/PlusJakartaSans_700',
        'packages/google_fonts/PlusJakartaSans_bold',
        'packages/google_fonts/PlusJakartaSans_800',
        'packages/google_fonts/PlusJakartaSans_300',
        'Roboto',
        '.SF Pro Text',
        '.SF Pro Display',
        '.AppleSystemUIFont',
      ];

      for (final family in pjsFamilies) {
        final loader = FontLoader(family);
        loader.addFont(Future.value(byteData));
        await loader.load();
      }
    }

    // 2. JetBrains Mono
    final monoFile = File('assets/fonts/JetBrainsMono.ttf');
    if (await monoFile.exists()) {
      final bytes = await monoFile.readAsBytes();
      final byteData = ByteData.view(bytes.buffer);

      final monoFamilies = [
        'JetBrainsMono',
        'JetBrains Mono',
        'packages/google_fonts/JetBrainsMono',
        'packages/google_fonts/JetBrainsMono_regular',
        'packages/google_fonts/JetBrainsMono_500',
        'packages/google_fonts/JetBrainsMono_600',
        'packages/google_fonts/JetBrainsMono_700',
        'packages/google_fonts/JetBrainsMono_bold',
        'Courier',
        'monospace',
      ];

      for (final family in monoFamilies) {
        final loader = FontLoader(family);
        loader.addFont(Future.value(byteData));
        await loader.load();
      }
    }

    // 3. Material Icons
    final iconsFile = File('assets/fonts/MaterialIcons-Regular.otf');
    if (await iconsFile.exists()) {
      final bytes = await iconsFile.readAsBytes();
      final byteData = ByteData.view(bytes.buffer);

      final iconFamilies = [
        'MaterialIcons',
        'Material Icons',
      ];

      for (final family in iconFamilies) {
        final loader = FontLoader(family);
        loader.addFont(Future.value(byteData));
        await loader.load();
      }
    }

    _fontsLoaded = true;
  }
}
