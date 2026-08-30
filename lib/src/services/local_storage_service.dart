import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';

abstract class LocalStorageService {
  const LocalStorageService();

  Future<void> initDB();

  Future<void> savePreference({required String key, required String data});

  String? getPreference({required String key});

  Future<void> deletePreference({required String key});
}

class LocalStorageServiceImpl implements LocalStorageService {
  LocalStorageServiceImpl({HiveInterface? hive}) : _hive = hive ?? Hive;

  final HiveInterface _hive;
  late Box<String> _box;

  @override
  Future<void> initDB() async {
    _box = await _hive.openBox<String>('kortex_app_box');
  }

  @override
  String? getPreference({required String key}) {
    return _box.get(key);
  }

  @override
  Future<void> savePreference({
    required String key,
    required String data,
  }) async {
    await _box.put(key, data);
  }

  @override
  Future<void> deletePreference({required String key}) async {
    try {
      await _box.delete(key);
    } on Exception catch (e) {
      Logger().e(e);
    }
  }

  @visibleForTesting
  // ignore: use_setters_to_change_properties, for testing dependency injection
  void setBox(Box<String> box) => _box = box;
}
