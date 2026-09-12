import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

/// Test helper to wrap widgets in a consistent high-resolution device canvas
/// and capture pixel-perfect PNG marketing screenshots.
class ScreenshotTestWrapper {
  static const Size standardMobileSize = Size(390, 844); // iPhone 14/15 logical

  static Widget wrapForScreenshot({
    required Widget child,
    required GlobalKey boundaryKey,
    ThemeData? theme,
    Brightness brightness = Brightness.dark,
  }) {
    return RepaintBoundary(
      key: boundaryKey,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: (theme ??
                  (brightness == Brightness.dark
                      ? AppTheme.darkTheme
                      : AppTheme.lightTheme))
              .copyWith(
            textTheme: (brightness == Brightness.dark
                    ? AppTheme.darkTheme.textTheme
                    : AppTheme.lightTheme.textTheme)
                .apply(
              fontFamily: 'PlusJakartaSans',
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            backgroundColor: const Color(0xFF0B0F17),
            body: child,
          ),
        ),
      ),
    );
  }

  static Future<void> captureAndSave({
    required WidgetTester tester,
    required GlobalKey boundaryKey,
    required String screenshotName,
    List<String> outputDirectories = const [
      'storage/screenshots/marketing',
      'docs/screenshots/marketing',
    ],
    double pixelRatio = 3.0,
  }) async {
    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      for (final dirPath in outputDirectories) {
        final file = File('$dirPath/$screenshotName.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(pngBytes);
      }
    });
  }
}
