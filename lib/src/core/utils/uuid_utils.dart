import 'dart:math';

/// RFC4122 v4 compliant UUID generator and validator.
class UuidUtils {
  const UuidUtils._();

  static final Random _random = Random.secure();
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Generates a random RFC4122 version 4 UUID.
  static String generate() {
    final values = List<int>.generate(16, (i) => _random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // RFC4122 version 4
    values[8] = (values[8] & 0x3f) | 0x80; // RFC4122 variant

    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Checks if the provided string is a valid UUID.
  static bool isValidUuid(String? value) {
    if (value == null || value.isEmpty) return false;
    return _uuidRegex.hasMatch(value);
  }
}
