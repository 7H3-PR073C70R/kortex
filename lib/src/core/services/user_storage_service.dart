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

  Future<void> saveUserDisplayName(String displayName);

  Future<void> saveUserAvatarUrl(String avatarUrl);

  Future<void> saveProStatus({required bool isPro});

  bool isProSubscriber();

  void clearStorage();

  Future<void> initStorage();

  bool isTokenExpired();
}

class UserStorageServiceImpl implements UserStorageService {
  UserStorageServiceImpl(
    this._localStorageService, {
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
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
  String? _cachedDisplayName;
  String? _cachedAvatarUrl;

  @override
  Future<void> initStorage() async {
    try {
      _cachedToken = await _secureStorage.read(key: _tokenKey);
      _cachedRefreshToken = await _secureStorage.read(key: _refreshTokenKey);
      _cachedEmail =
          await _secureStorage.read(key: _emailKey) ??
          _localStorageService.getPreference(key: _emailKey);
    } on Object {
      _cachedToken = null;
      _cachedRefreshToken = null;
      _cachedEmail = _localStorageService.getPreference(key: _emailKey);
    }

    // Defensive migration: Purge legacy sensitive tokens from plaintext SharedPreferences if present
    unawaited(_safeLocalDelete(_tokenKey));
    unawaited(_safeLocalDelete(_refreshTokenKey));

    _cachedDisplayName = _localStorageService.getPreference(
      key: PrefKeys.userDisplayName,
    );
    _cachedAvatarUrl = _localStorageService.getPreference(
      key: PrefKeys.userAvatarUrl,
    );
  }

  void _initCache() {
    unawaited(initStorage());
  }

  static String? _sanitizeToken(String? raw) {
    if (raw == null) return null;
    var clean = raw.trim();
    if (clean.isEmpty) return null;

    // Strip surrounding quotes if accidentally JSON-encoded
    if ((clean.startsWith('"') && clean.endsWith('"')) ||
        (clean.startsWith("'") && clean.endsWith("'"))) {
      clean = clean.substring(1, clean.length - 1).trim();
    }

    // Strip duplicate 'Bearer ' prefix if present
    if (clean.toLowerCase().startsWith('bearer ')) {
      clean = clean.substring(7).trim();
    }

    // A valid JWT or key is single-line printable ASCII.
    // Reject HTML strings, error pages, or error noise.
    if (clean.contains(' ') ||
        clean.contains('\n') ||
        clean.contains('\r') ||
        clean.contains('\t') ||
        clean.contains('<html') ||
        clean.contains('<head') ||
        clean.contains('400 Bad Request')) {
      return null;
    }

    return clean.isNotEmpty ? clean : null;
  }

  @override
  String? getToken() {
    final sanitized = _sanitizeToken(_cachedToken);
    if (_cachedToken != null && _cachedToken!.isNotEmpty && sanitized == null) {
      _cachedToken = null;
      unawaited(_safeSecureDelete(_tokenKey));
    }
    return _cachedToken = sanitized;
  }

  @override
  String? getRefreshToken() {
    final sanitized = _sanitizeToken(_cachedRefreshToken);
    if (_cachedRefreshToken != null &&
        _cachedRefreshToken!.isNotEmpty &&
        sanitized == null) {
      _cachedRefreshToken = null;
      unawaited(_safeSecureDelete(_refreshTokenKey));
    }
    return _cachedRefreshToken = sanitized;
  }

  Map<String, dynamic>? _decodeJwtPayload() {
    final token = getToken();
    if (token == null || !token.contains('.')) return null;
    try {
      final parts = token.split('.');
      if (parts.length >= 2) {
        final payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
        final remainder = payload.length % 4;
        final padded = remainder == 0
            ? payload
            : payload.padRight(payload.length + (4 - remainder), '=');
        final decoded = utf8.decode(base64.decode(padded));
        final map = jsonDecode(decoded);
        if (map is Map<String, dynamic>) {
          return map;
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  @override
  bool isTokenExpired() {
    final token = getToken();
    if (token == null || token.isEmpty) return true;
    final map = _decodeJwtPayload();
    if (map == null) {
      return false;
    }
    final exp = map['exp'];
    if (exp == null) return false;
    final expSeconds = exp is int ? exp : int.tryParse(exp.toString());
    if (expSeconds == null) return false;
    final expiryTime = DateTime.fromMillisecondsSinceEpoch(
      expSeconds * 1000,
      isUtc: true,
    );
    // Allow a 15-second grace window to prevent edge-case expirations during routing
    return DateTime.now().toUtc().isAfter(
      expiryTime.subtract(const Duration(seconds: 15)),
    );
  }

  @override
  String? getUserId() {
    final map = _decodeJwtPayload();
    return map?['sub'] as String? ?? map?['id'] as String?;
  }

  @override
  String? getUserDisplayName() {
    if (_cachedDisplayName != null && _cachedDisplayName!.trim().isNotEmpty) {
      return _cachedDisplayName!.trim();
    }
    final fromStorage = _localStorageService.getPreference(
      key: PrefKeys.userDisplayName,
    );
    if (fromStorage != null && fromStorage.trim().isNotEmpty) {
      return _cachedDisplayName = fromStorage.trim();
    }
    final map = _decodeJwtPayload();
    if (map == null) return null;
    final metadata = map['user_metadata'] as Map<String, dynamic>?;
    final name =
        metadata?['display_name'] as String? ??
        metadata?['full_name'] as String? ??
        metadata?['name'] as String? ??
        map['display_name'] as String? ??
        map['full_name'] as String? ??
        map['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final email = map['email'] as String?;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return null;
  }

  @override
  String? getUserAvatarUrl() {
    if (_cachedAvatarUrl != null && _cachedAvatarUrl!.trim().isNotEmpty) {
      return _cachedAvatarUrl!.trim();
    }
    final fromStorage = _localStorageService.getPreference(
      key: PrefKeys.userAvatarUrl,
    );
    if (fromStorage != null && fromStorage.trim().isNotEmpty) {
      return _cachedAvatarUrl = fromStorage.trim();
    }
    final map = _decodeJwtPayload();
    if (map == null) return null;
    final metadata = map['user_metadata'] as Map<String, dynamic>?;
    return metadata?['avatar_url'] as String? ??
        metadata?['picture'] as String? ??
        metadata?['photo_url'] as String? ??
        map['avatar_url'] as String? ??
        map['picture'] as String? ??
        map['photo_url'] as String?;
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
    final clean = _sanitizeToken(token);
    _cachedToken = clean;
    if (clean == null) {
      await _safeSecureDelete(_tokenKey);
      await _safeLocalDelete(_tokenKey);
      return;
    }
    try {
      await _secureStorage.write(key: _tokenKey, value: clean);
      // Ensure plaintext preference is deleted
      await _safeLocalDelete(_tokenKey);
    } on Object {
      return;
    }
  }

  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    final clean = _sanitizeToken(refreshToken);
    _cachedRefreshToken = clean;
    if (clean == null) {
      await _safeSecureDelete(_refreshTokenKey);
      await _safeLocalDelete(_refreshTokenKey);
      return;
    }
    try {
      await _secureStorage.write(key: _refreshTokenKey, value: clean);
      // Ensure plaintext preference is deleted
      await _safeLocalDelete(_refreshTokenKey);
    } on Object {
      return;
    }
  }

  @override
  Future<void> saveAuthTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await saveToken(accessToken);
    await saveRefreshToken(refreshToken);
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
  Future<void> saveUserDisplayName(String displayName) async {
    final clean = displayName.trim();
    _cachedDisplayName = clean;
    try {
      await _localStorageService.savePreference(
        key: PrefKeys.userDisplayName,
        data: clean,
      );
    } on Object {
      return;
    }
  }

  @override
  Future<void> saveUserAvatarUrl(String avatarUrl) async {
    final clean = avatarUrl.trim();
    _cachedAvatarUrl = clean;
    try {
      await _localStorageService.savePreference(
        key: PrefKeys.userAvatarUrl,
        data: clean,
      );
    } on Object {
      return;
    }
  }

  @override
  void clearStorage() {
    _cachedToken = null;
    _cachedRefreshToken = null;
    _cachedEmail = null;
    _cachedDisplayName = null;
    _cachedAvatarUrl = null;
    unawaited(_safeSecureDelete(_tokenKey));
    unawaited(_safeSecureDelete(_refreshTokenKey));
    unawaited(_safeSecureDelete(_emailKey));
    unawaited(_safeLocalDelete(_tokenKey));
    unawaited(_safeLocalDelete(_refreshTokenKey));
    unawaited(_safeLocalDelete(PrefKeys.isProSubscriber));
    unawaited(_safeLocalDelete(_emailKey));
    unawaited(_safeLocalDelete(PrefKeys.userDisplayName));
    unawaited(_safeLocalDelete(PrefKeys.userAvatarUrl));
  }
}
