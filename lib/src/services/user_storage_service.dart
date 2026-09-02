import 'dart:async';
import 'dart:convert';
import 'package:kortex/src/services/local_storage_service.dart';

abstract class UserStorageService {
  Future<void> saveToken(String token);

  String? getToken();

  String? getUserId();

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
  String? getUserId() {
    final token = getToken();
    if (token == null || !token.contains('.')) return null;
    try {
      final parts = token.split('.');
      if (parts.length >= 2) {
        final normalized = base64Url.normalize(parts[1]);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final map = jsonDecode(decoded) as Map<String, dynamic>;
        return map['sub'] as String? ?? map['id'] as String?;
      }
    } on Object {
      return null;
    }
    return null;
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
