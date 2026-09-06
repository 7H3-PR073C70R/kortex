import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
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

  String? getUserEmail();

  Future<void> saveUserEmail(String email);

  Future<void> saveProStatus({required bool isPro});

  bool isProSubscriber();

  void clearStorage();

  Future<void> initStorage();
}

class UserStorageServiceImpl implements UserStorageService {
  UserStorageServiceImpl(
    this._localStorageService, {
    FlutterSecureStorage? secureStorage,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _initCache();
  }

  final LocalStorageService _localStorageService;
  final FlutterSecureStorage _secureStorage;

  final _tokenKey = '__token';
  final _refreshTokenKey = '__refresh_token';
  final _emailKey = '__user_email';

  String? _cachedToken;
  String? _cachedRefreshToken;
  String? _cachedEmail;

  @override
  Future<void> initStorage() async {
    try {
      _cachedToken = await _secureStorage.read(key: _tokenKey) ??
          _localStorageService.getPreference(key: _tokenKey);
      _cachedRefreshToken = await _secureStorage.read(key: _refreshTokenKey) ??
          _localStorageService.getPreference(key: _refreshTokenKey);
      _cachedEmail = await _secureStorage.read(key: _emailKey) ??
          _localStorageService.getPreference(key: _emailKey);
    } on Object {
      _cachedToken = _localStorageService.getPreference(key: _tokenKey);
      _cachedRefreshToken =
          _localStorageService.getPreference(key: _refreshTokenKey);
      _cachedEmail = _localStorageService.getPreference(key: _emailKey);
    }
  }

  void _initCache() {
    _cachedToken ??= _localStorageService.getPreference(key: _tokenKey);
    _cachedRefreshToken ??=
        _localStorageService.getPreference(key: _refreshTokenKey);
    _cachedEmail ??= _localStorageService.getPreference(key: _emailKey);
    unawaited(initStorage());
  }

  @override
  String? getToken() {
    return _cachedToken ?? _localStorageService.getPreference(key: _tokenKey);
  }

  @override
  String? getRefreshToken() {
    return _cachedRefreshToken ??
        _localStorageService.getPreference(key: _refreshTokenKey);
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
  String? getUserEmail() {
    final map = _decodeJwtPayload();
    final email = map?['email'] as String?;
    if (email != null && email.trim().isNotEmpty) {
      return email.trim();
    }
    return _cachedEmail ?? _localStorageService.getPreference(key: _emailKey);
  }

  @override
  Future<void> saveUserEmail(String email) async {
    final clean = email.trim();
    _cachedEmail = clean;
    try {
      await _secureStorage.write(key: _emailKey, value: clean);
      await _localStorageService.savePreference(
        key: _emailKey,
        data: clean,
      );
    } on Object {
      return;
    }
  }

  @override
  Future<void> saveToken(String token) async {
    _cachedToken = token;
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
      await _localStorageService.savePreference(key: _tokenKey, data: token);
    } on Object {
      return;
    }
  }

  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    _cachedRefreshToken = refreshToken;
    try {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
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
    _cachedToken = accessToken;
    _cachedRefreshToken = refreshToken;
    try {
      await _secureStorage.write(key: _tokenKey, value: accessToken);
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
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
  Future<void> saveProStatus({required bool isPro}) async {
    try {
      await _localStorageService.savePreference(
        key: PrefKeys.isProSubscriber,
        data: isPro ? 'true' : 'false',
      );
    } on Object {
      return;
    }
  }

  @override
  bool isProSubscriber() {
    try {
      final value = _localStorageService.getPreference(
        key: PrefKeys.isProSubscriber,
      );
      return value == 'true';
    } on Object {
      return false;
    }
  }

  Future<void> _safeSecureDelete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } on Object {
      // Ignore channel/missing plugin errors in environments without secure hardware
    }
  }

  Future<void> _safeLocalDelete(String key) async {
    try {
      await _localStorageService.deletePreference(key: key);
    } on Object {
      // Ignore errors
    }
  }

  @override
  void clearStorage() {
    _cachedToken = null;
    _cachedRefreshToken = null;
    _cachedEmail = null;
    unawaited(_safeSecureDelete(_tokenKey));
    unawaited(_safeSecureDelete(_refreshTokenKey));
    unawaited(_safeSecureDelete(_emailKey));
    unawaited(_safeLocalDelete(_tokenKey));
    unawaited(_safeLocalDelete(_refreshTokenKey));
    unawaited(_safeLocalDelete(PrefKeys.isProSubscriber));
    unawaited(_safeLocalDelete(_emailKey));
  }
}
