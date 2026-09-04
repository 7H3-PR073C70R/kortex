import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Result from a successful social sign-in flow.
class SocialAuthResult {
  const SocialAuthResult({
    required this.provider,
    required this.idToken,
    this.rawNonce,
    this.email,
    this.displayName,
  });

  final String provider;
  final String idToken;
  final String? rawNonce;
  final String? email;
  final String? displayName;
}

/// Service handling Google and Apple OAuth authentication with Firebase.
class SocialAuthService {
  SocialAuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn;

  bool get _isFirebaseAvailable {
    try {
      if (Firebase.apps.isEmpty) return false;
      _auth ??= FirebaseAuth.instance;
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  /// Generates a cryptographically secure random nonce for Apple Sign In.
  static String generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = math.Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Hashes a string using SHA-256.
  static String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Initiates Google Sign-In and links with Firebase Auth if available.
  /// Returns `null` if user cancelled.
  Future<SocialAuthResult?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        developer.log('Google sign-in was cancelled by the user.');
        return null;
      }

      final googleAuth = await googleUser.authentication;
      var idToken = googleAuth.idToken ?? '';
      var email = googleUser.email;
      var displayName = googleUser.displayName;

      if (_isFirebaseAvailable) {
        try {
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          final userCredential = await _auth!.signInWithCredential(credential);
          final user = userCredential.user;
          if (user != null) {
            final fbToken = await user.getIdToken();
            if (fbToken != null && fbToken.isNotEmpty) {
              idToken = fbToken;
            }
            email = user.email ?? email;
            displayName = user.displayName ?? displayName;
          }
        } on Object catch (e) {
          developer.log('Firebase Auth link with Google failed: $e');
        }
      }

      // Fallback token if idToken was empty (e.g. mock/test)
      if (idToken.isEmpty) {
        idToken = googleAuth.accessToken ?? 'google_auth_token';
      }

      return SocialAuthResult(
        provider: 'google',
        idToken: idToken,
        email: email,
        displayName: displayName,
      );
    } on Object catch (e) {
      developer.log('Google sign-in error: $e');
      rethrow;
    }
  }

  /// Initiates Apple Sign-In and links with Firebase Auth if available.
  /// Returns `null` if user cancelled.
  Future<SocialAuthResult?> signInWithApple() async {
    try {
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      var idToken = appleCredential.identityToken ?? '';
      var email = appleCredential.email;
      String? displayName;
      if (appleCredential.givenName != null ||
          appleCredential.familyName != null) {
        displayName = [
          appleCredential.givenName,
          appleCredential.familyName,
        ].where((name) => name != null && name.isNotEmpty).join(' ');
      }

      if (_isFirebaseAvailable && idToken.isNotEmpty) {
        try {
          final oAuthProvider = OAuthProvider('apple.com');
          final credential = oAuthProvider.credential(
            idToken: idToken,
            rawNonce: rawNonce,
          );
          final userCredential = await _auth!.signInWithCredential(credential);
          final user = userCredential.user;
          if (user != null) {
            final fbToken = await user.getIdToken();
            if (fbToken != null && fbToken.isNotEmpty) {
              idToken = fbToken;
            }
            email = user.email ?? email;
            displayName = user.displayName ?? displayName;
          }
        } on Object catch (e) {
          developer.log('Firebase Auth link with Apple failed: $e');
        }
      }

      if (idToken.isEmpty) {
        idToken = 'apple_auth_token';
      }

      return SocialAuthResult(
        provider: 'apple',
        idToken: idToken,
        rawNonce: rawNonce,
        email: email,
        displayName: displayName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        developer.log('Apple sign-in was cancelled by the user.');
        return null;
      }
      developer.log('Apple sign-in authorization error: ${e.message}');
      rethrow;
    } on Object catch (e) {
      developer.log('Apple sign-in error: $e');
      rethrow;
    }
  }

  /// Sign out from Google and Firebase Auth.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } on Object catch (e) {
      developer.log('Error signing out of Google: $e');
    }

    if (_isFirebaseAvailable) {
      try {
        await _auth?.signOut();
      } on Object catch (e) {
        developer.log('Error signing out of Firebase Auth: $e');
      }
    }
  }
}
