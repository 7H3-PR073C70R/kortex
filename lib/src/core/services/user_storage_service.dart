import 'dart:async';
import 'dart:convert';
import 'package:kortex/src/core/services/local_storage_service.dart';

abstract class UserStorageService {
  Future<void> saveToken(String token);

  String? getToken();

  Future<void> saveRefreshToken(String refreshToken);

  String? getRefreshToken();

  Future<void> saveAuthTokens({
    required String accessToken,
    required String refreshToken,
  });

  String? getUserId();

  String? getUserDisplayName();

  String? getUserAvatarUrl();

  void clearStorage();
}

class UserStorageServiceImpl implements UserStorageService {
  UserStorageServiceImpl(this._localStorageService);
  final LocalStorageService _localStorageService;

  final _tokenKey = '__token';
  final _refreshTokenKey = '__refresh_token';

  @override
  String? getToken() {
    try {
      return _localStorageService.getPreference(key: _tokenKey);
    } on Object {
      return null;
    }
  }

  @override
  String? getRefreshToken() {
    try {
      return _localStorageService.getPreference(key: _refreshTokenKey);
    } on Object {
      return null;
    }
  }

  Map<String, dynamic>? _decodeJwtPayload() {
    final token = getToken();
    if (token == null || !token.contains('.')) return null;
    try {
      final parts = token.split('.');
      if (parts.length >= 2) {
        final normalized = base64Url.normalize(parts[1]);
        final decoded = utf8.decode(base64Url.decode(normalized));
        return jsonDecode(decoded) as Map<String, dynamic>;
      }
    } on Object {
      return null;
    }
    return null;
  }

  @override
  String? getUserId() {
    final map = _decodeJwtPayload();
    return map?['sub'] as String? ?? map?['id'] as String?;
  }

  @override
  String? getUserDisplayName() {
    final map = _decodeJwtPayload();
    if (map == null) return null;
    final metadata = map['user_metadata'] as Map<String, dynamic>?;
    final name = metadata?['display_name'] as String? ??
        metadata?['full_name'] as String? ??
        metadata?['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final email = map['email'] as String?;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return null;
  }

  @override
  String? getUserAvatarUrl() {
    final map = _decodeJwtPayload();
    if (map == null) return null;
    final metadata = map['user_metadata'] as Map<String, dynamic>?;
    return metadata?['avatar_url'] as String? ??
        metadata?['picture'] as String? ??
        metadata?['photo_url'] as String?;
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
  Future<void> saveRefreshToken(String refreshToken) async {
    try {
      await _localStorageService.savePreference(
        key: _refreshTokenKey,
        data: refreshToken,
      );
    } on Object {
      return;
    }
  }

  @override
  Future<void> saveAuthTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await _localStorageService.savePreference(
        key: _tokenKey,
        data: accessToken,
      );
      await _localStorageService.savePreference(
        key: _refreshTokenKey,
        data: refreshToken,
      );
    } on Object {
      return;
    }
  }

  @override
  void clearStorage() {
    unawaited(_localStorageService.deletePreference(key: _tokenKey));
    unawaited(_localStorageService.deletePreference(key: _refreshTokenKey));
  }
}
