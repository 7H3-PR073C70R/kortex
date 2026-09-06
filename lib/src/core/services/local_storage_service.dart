import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class LocalStorageService {
  const LocalStorageService();

  Future<void> initDB();

  Future<void> savePreference({required String key, required String data});

  String? getPreference({required String key});

  Future<void> deletePreference({required String key});
}

class LocalStorageServiceImpl implements LocalStorageService {
  LocalStorageServiceImpl({SharedPreferences? preferences})
      : _preferences = preferences;

  SharedPreferences? _preferences;

  @override
  Future<void> initDB() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  @override
  String? getPreference({required String key}) {
    return _preferences?.getString(key);
  }

  @override
  Future<void> savePreference({
    required String key,
    required String data,
  }) async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    _preferences = prefs;
    await prefs.setString(key, data);
  }

  @override
  Future<void> deletePreference({required String key}) async {
    try {
      final prefs = _preferences ?? await SharedPreferences.getInstance();
      _preferences = prefs;
      await prefs.remove(key);
    } on Exception catch (e) {
      Logger().e(e);
    }
  }

  @visibleForTesting
  // ignore: use_setters_to_change_properties, for testing dependency injection
  void setPreferences(SharedPreferences preferences) =>
      _preferences = preferences;
}
