import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/features/auth/data/models/user_profile_model.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';

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

  bool hasActiveSession();

  Future<void> saveUserProfile(UserProfileEntity profile);

  UserProfileEntity? getCachedUserProfile();
}

class UserStorageServiceImpl implements UserStorageService {
  UserStorageServiceImpl(
    this._localStorageService, {
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              mOptions: MacOsOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final LocalStorageService _localStorageService;
  final FlutterSecureStorage _secureStorage;

  final _tokenKey = '__token';
  final _refreshTokenKey = '__refresh_token';
  final _emailKey = '__user_email';
  // Stored in secure enclave — NOT plaintext SharedPreferences.
  final _proStatusKey = '__is_pro_subscriber';

  String? _cachedToken;
  String? _cachedRefreshToken;
  String? _cachedEmail;
  String? _cachedDisplayName;
  String? _cachedAvatarUrl;
  bool? _cachedProStatus;
  UserProfileEntity? _cachedProfile;

  @override
  bool hasActiveSession() {
    final refreshToken = getRefreshToken();
    if (refreshToken != null && refreshToken.trim().isNotEmpty) {
      return true;
    }
    final token = getToken();
    if (token != null && token.trim().isNotEmpty && !isTokenExpired()) {
      return true;
    }
    return false;
  }

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

    // Hydration fallback: If secure storage read failed or returned empty on desktop OS, load from local storage
    _cachedToken = _sanitizeToken(_cachedToken) ??
        _sanitizeToken(_localStorageService.getPreference(key: _tokenKey));
    _cachedRefreshToken = _sanitizeToken(_cachedRefreshToken) ??
        _sanitizeToken(_localStorageService.getPreference(key: _refreshTokenKey));
    _cachedEmail = _cachedEmail ?? _localStorageService.getPreference(key: _emailKey);

    // Read pro status from secure storage or fallback to local storage
    try {
      final rawProStatus = await _secureStorage.read(key: _proStatusKey);
      if (rawProStatus != null) {
        _cachedProStatus = rawProStatus == 'true';
      }
    } on Object catch (_) {}
    if (_cachedProStatus == null) {
      final localPro = _localStorageService.getPreference(key: _proStatusKey);
      if (localPro != null) {
        _cachedProStatus = localPro == 'true';
      }
    }

    // Migrate legacy plaintext pro status flag if present.
    final legacyPro = _localStorageService.getPreference(key: PrefKeys.isProSubscriber);
    if (legacyPro != null) {
      _cachedProStatus = legacyPro == 'true';
      unawaited(_secureStorage.write(key: _proStatusKey, value: legacyPro));
      unawaited(_safeLocalDelete(PrefKeys.isProSubscriber));
    }

    _cachedDisplayName = _localStorageService.getPreference(
      key: PrefKeys.userDisplayName,
    );
    _cachedAvatarUrl = _localStorageService.getPreference(
      key: PrefKeys.userAvatarUrl,
    );

    final rawProfile = _localStorageService.getPreference(
      key: PrefKeys.cachedUserProfile,
    );
    if (rawProfile != null && rawProfile.trim().isNotEmpty) {
      try {
        final json = jsonDecode(rawProfile) as Map<String, dynamic>;
        _cachedProfile = UserProfileModel.fromJson(json).toEntity();
      } on Object catch (_) {}
    }
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
      unawaited(_safeLocalDelete(_tokenKey));
    }
    if (sanitized == null || sanitized.isEmpty) {
      final fallback = _sanitizeToken(_localStorageService.getPreference(key: _tokenKey));
      if (fallback != null && fallback.isNotEmpty) {
        return _cachedToken = fallback;
      }
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
      unawaited(_safeLocalDelete(_refreshTokenKey));
    }
    if (sanitized == null || sanitized.isEmpty) {
      final fallback = _sanitizeToken(_localStorageService.getPreference(key: _refreshTokenKey));
      if (fallback != null && fallback.isNotEmpty) {
        return _cachedRefreshToken = fallback;
      }
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
    final map = _decodeJwtPayload();
    final metadata = map?['user_metadata'] as Map<String, dynamic>?;
    final jwtName =
        metadata?['display_name'] as String? ??
        metadata?['full_name'] as String? ??
        metadata?['name'] as String? ??
        map?['display_name'] as String? ??
        map?['full_name'] as String? ??
        map?['name'] as String?;
    final email = map?['email'] as String? ?? _cachedEmail;
    final emailPrefix =
        (email != null && email.contains('@')) ? email.split('@').first : '';

    if (_cachedDisplayName != null && _cachedDisplayName!.trim().isNotEmpty) {
      final cached = _cachedDisplayName!.trim();
      if (emailPrefix.isNotEmpty &&
          cached == emailPrefix &&
          jwtName != null &&
          jwtName.trim().isNotEmpty &&
          jwtName.trim() != emailPrefix) {
        final cleanJwtName = jwtName.trim();
        _cachedDisplayName = cleanJwtName;
        unawaited(
          _localStorageService.savePreference(
            key: PrefKeys.userDisplayName,
            data: cleanJwtName,
          ),
        );
        return cleanJwtName;
      }
      return cached;
    }

    final fromStorage = _localStorageService.getPreference(
      key: PrefKeys.userDisplayName,
    );
    if (fromStorage != null && fromStorage.trim().isNotEmpty) {
      final stored = fromStorage.trim();
      if (emailPrefix.isNotEmpty &&
          stored == emailPrefix &&
          jwtName != null &&
          jwtName.trim().isNotEmpty &&
          jwtName.trim() != emailPrefix) {
        final cleanJwtName = jwtName.trim();
        _cachedDisplayName = cleanJwtName;
        unawaited(
          _localStorageService.savePreference(
            key: PrefKeys.userDisplayName,
            data: cleanJwtName,
          ),
        );
        return cleanJwtName;
      }
      return _cachedDisplayName = stored;
    }

    if (jwtName != null && jwtName.trim().isNotEmpty) {
      final cleanJwtName = jwtName.trim();
      if (emailPrefix.isEmpty || cleanJwtName != emailPrefix) {
        _cachedDisplayName = cleanJwtName;
        unawaited(
          _localStorageService.savePreference(
            key: PrefKeys.userDisplayName,
            data: cleanJwtName,
          ),
        );
      }
      return cleanJwtName;
    }

    if (emailPrefix.isNotEmpty) {
      return emailPrefix;
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
    } on Object {
      // Secure storage write failed on desktop without keychain sandbox permissions
    }
    try {
      await _localStorageService.savePreference(
        key: _tokenKey,
        data: clean,
      );
    } on Object catch (_) {}
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
    } on Object {
      // Secure storage write failed
    }
    try {
      await _localStorageService.savePreference(
        key: _refreshTokenKey,
        data: clean,
      );
    } on Object catch (_) {}
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
    _cachedProStatus = isPro;
    final valueStr = isPro ? 'true' : 'false';
    try {
      await _secureStorage.write(
        key: _proStatusKey,
        value: valueStr,
      );
    } on Object catch (_) {}
    try {
      await _localStorageService.savePreference(
        key: _proStatusKey,
        data: valueStr,
      );
      unawaited(_safeLocalDelete(PrefKeys.isProSubscriber));
    } on Object catch (_) {}
  }

  @override
  bool isProSubscriber() {
    // Use the in-memory cache populated during initStorage().
    return _cachedProStatus ?? false;
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
    if (clean.isEmpty) return;
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
  Future<void> saveUserProfile(UserProfileEntity profile) async {
    _cachedProfile = profile;
    final incomingName = profile.displayName?.trim();
    final emailPrefix =
        profile.email.contains('@') ? profile.email.split('@').first : '';
    if (incomingName != null &&
        incomingName.isNotEmpty &&
        incomingName != emailPrefix) {
      _cachedDisplayName = incomingName;
      try {
        await _localStorageService.savePreference(
          key: PrefKeys.userDisplayName,
          data: incomingName,
        );
      } on Object catch (_) {}
    }
    if (profile.photoUrl != null && profile.photoUrl!.trim().isNotEmpty) {
      _cachedAvatarUrl = profile.photoUrl!.trim();
      try {
        await _localStorageService.savePreference(
          key: PrefKeys.userAvatarUrl,
          data: profile.photoUrl!.trim(),
        );
      } on Object catch (_) {}
    }
    try {
      final model = UserProfileModel(
        id: profile.id,
        email: profile.email,
        displayName: profile.displayName,
        photoUrl: profile.photoUrl,
        targetTrack: profile.targetTrack,
        dailyCardTarget: profile.dailyCardTarget,
        retentionBenchmark: profile.retentionBenchmark,
        level: profile.level,
        streakDays: profile.streakDays,
        streakFreezeCount: profile.streakFreezeCount,
        timezone: profile.timezone,
        xpPoints: profile.xpPoints,
        subscriptionTier: profile.subscriptionTier,
        isOnboarded: profile.isOnboarded,
      );
      await _localStorageService.savePreference(
        key: PrefKeys.cachedUserProfile,
        data: jsonEncode(model.toJson()),
      );
    } on Object catch (_) {}
  }

  @override
  UserProfileEntity? getCachedUserProfile() {
    if (_cachedProfile != null) return _cachedProfile;
    try {
      final raw = _localStorageService.getPreference(
        key: PrefKeys.cachedUserProfile,
      );
      if (raw != null && raw.trim().isNotEmpty) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return _cachedProfile = UserProfileModel.fromJson(json).toEntity();
      }
    } on Object catch (_) {}
    return null;
  }

  @override
  void clearStorage() {
    _cachedToken = null;
    _cachedRefreshToken = null;
    _cachedEmail = null;
    _cachedDisplayName = null;
    _cachedAvatarUrl = null;
    _cachedProStatus = null;
    _cachedProfile = null;
    unawaited(_safeSecureDelete(_tokenKey));
    unawaited(_safeSecureDelete(_refreshTokenKey));
    unawaited(_safeSecureDelete(_emailKey));
    unawaited(_safeSecureDelete(_proStatusKey));
    unawaited(_safeLocalDelete(_tokenKey));
    unawaited(_safeLocalDelete(_refreshTokenKey));
    unawaited(_safeLocalDelete(_proStatusKey));
    // Belt-and-suspenders: also wipe legacy plaintext pro key on sign-out.
    unawaited(_safeLocalDelete(PrefKeys.isProSubscriber));
    unawaited(_safeLocalDelete(_emailKey));
    unawaited(_safeLocalDelete(PrefKeys.userDisplayName));
    unawaited(_safeLocalDelete(PrefKeys.userAvatarUrl));
    unawaited(_safeLocalDelete(PrefKeys.cachedUserProfile));
  }
}
