import 'dart:async';

import 'package:kortex/bootstrap.dart';
import 'package:kortex/src/app/page/app.dart';
import 'package:kortex/src/core/enums/enums.dart';

void main() {
  unawaited(
    bootstrap(
      builder: App.new,
      environment: Environment.staging,
    ),
  );
}
