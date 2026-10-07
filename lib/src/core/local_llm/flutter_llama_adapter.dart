/// Platform-conditional adapter for flutter_llama.
///
/// On native (iOS, Android, macOS, Windows, Linux): re-exports the real
/// flutter_llama symbols including dart:ffi-backed types.
///
/// On web: provides pure-Dart no-op stubs so the web build never touches
/// package:ffi or dart:ffi.
library;
export 'flutter_llama_adapter_web.dart'
    if (dart.library.io) 'flutter_llama_adapter_native.dart';
