import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (
      screenshotName,
      screenshotBytes, [
      args,
    ]) async {
      final marketingFile =
          File('storage/screenshots/marketing/$screenshotName.png');
      await marketingFile.parent.create(recursive: true);
      await marketingFile.writeAsBytes(screenshotBytes);

      final docsFile =
          File('docs/screenshots/marketing/$screenshotName.png');
      await docsFile.parent.create(recursive: true);
      await docsFile.writeAsBytes(screenshotBytes);

      return true;
    },
  );
}
