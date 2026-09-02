import 'dart:async';
import 'package:kortex/src/services/local_storage_service.dart';

abstract class UserStorageService {
  Future<void> saveToken(String token);

  String? getToken();

  void clearStorage();
}

class UserStorageServiceImpl implements UserStorageService {
  UserStorageServiceImpl(this._localStorageService);
  final LocalStorageService _localStorageService;

  final _tokenKey = '__token';

  @override
  String? getToken() {
    try {
      return _localStorageService.getPreference(key: _tokenKey);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveToken(String token) async {
    try {
      await _localStorageService.savePreference(key: _tokenKey, data: token);
    } on Object {
      return;
    }
  }

  @override
  void clearStorage() {
    unawaited(_localStorageService.deletePreference(key: _tokenKey));
  }
}
