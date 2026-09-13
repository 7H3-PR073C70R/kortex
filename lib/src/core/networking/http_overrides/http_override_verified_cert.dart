import 'dart:io';
import 'package:flutter/foundation.dart';

class HTTPOverridesVerifiedCertificate extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // Strict Transport Security: Never bypass TLS certificate validation in production.
    // In local debug environments, standard platform certificates are verified.
    if (kDebugMode) {
      client.badCertificateCallback = (cert, host, port) {
        // Only permit localhost loopbacks during local instrumented test harnesses
        if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
          return true;
        }
        return false;
      };
    }
    return client;
  }
}
