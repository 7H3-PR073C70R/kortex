import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/integration/master_e2e_feature_validation_and_screenshots_test.dart'
    as master_test;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  master_test.main();
}
