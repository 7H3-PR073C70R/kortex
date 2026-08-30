import 'package:kortex/app/app.dart';
import 'package:kortex/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
