import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:url_launcher/url_launcher.dart';

/// Data returned when OAuth 2.0 authorization completes
class LmsOAuthResult {
  const LmsOAuthResult({
    required this.platform,
    required this.accessToken,
    required this.accountEmail,
    this.canvasDomain,
  });

  final String platform;
  final String accessToken;
  final String accountEmail;
  final String? canvasDomain;
}

/// Interactive OAuth 2.0 Single Sign-On Consent Dialog
/// Supports authentic Google Sign-In with Classroom scopes and Canvas API token verification.
class LmsOAuthDialog extends StatefulWidget {
  const LmsOAuthDialog({
    required this.platform,
    super.key,
    this.canvasDomain,
    this.googleSignIn,
    this.dio,
  });

  final String platform;
  final String? canvasDomain;
  final GoogleSignIn? googleSignIn;
  final Dio? dio;

  static Future<LmsOAuthResult?> show(
    BuildContext context, {
    required String platform,
    String? canvasDomain,
    GoogleSignIn? googleSignIn,
    Dio? dio,
  }) {
    final colors = context.colors;
    return showDialog<LmsOAuthResult>(
      context: context,
      barrierColor: colors.surfacePrimary.withAlpha(190),
      builder: (dialogContext) => LmsOAuthDialog(
        platform: platform,
        canvasDomain: canvasDomain,
        googleSignIn: googleSignIn,
        dio: dio,
      ),
    );
  }

  @override
  State<LmsOAuthDialog> createState() => _LmsOAuthDialogState();
}

class _LmsOAuthDialogState extends State<LmsOAuthDialog> {
  bool _isAuthorizing = false;
  String? _errorMessage;
  late final TextEditingController _canvasTokenController;
  late final GoogleSignIn _googleSignIn;
  late final Dio _dio;

  final List<String> _requestedScopes = [
    'View your enrolled courses, modules & syllabi',
    'Read course assignments, due dates & descriptions',
    'Read-only access (Cannot alter grades or submit)',
  ];

  @override
  void initState() {
    super.initState();
    _canvasTokenController = TextEditingController();
    _googleSignIn = widget.googleSignIn ??
        GoogleSignIn(
          scopes: [
            'email',
            'https://www.googleapis.com/auth/classroom.courses.readonly',
            'https://www.googleapis.com/auth/classroom.coursework.students.readonly',
            'https://www.googleapis.com/auth/classroom.announcements.readonly',
          ],
        );
    _dio = widget.dio ?? Dio();
  }

  @override
  void dispose() {
    _canvasTokenController.dispose();
    super.dispose();
  }

  String get _cleanedCanvasDomain {
    final raw = widget.canvasDomain ?? 'canvas.instructure.com';
    return raw
        .replaceAll(RegExp(r'^https?:\/\/'), '')
        .replaceAll(RegExp(r'\/.*$'), '')
        .trim();
  }

  Future<void> _launchCanvasSettings() async {
    AppFeedback.light();
    final url = 'https://$_cleanedCanvasDomain/profile/settings';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } on Object catch (_) {
      setState(() {
        _errorMessage = 'Could not open browser for $_cleanedCanvasDomain';
      });
    }
  }

  Future<void> _handleAuthorize() async {
    setState(() {
      _errorMessage = null;
    });

    if (widget.platform == 'canvas') {
      await _handleAuthorizeCanvas();
    } else {
      await _handleAuthorizeGoogle();
    }
  }

  Future<void> _handleAuthorizeGoogle() async {
    setState(() {
      _isAuthorizing = true;
    });

    AppFeedback.selection();
    unawaited(HapticFeedback.mediumImpact());

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the prompt
        if (mounted) {
          setState(() {
            _isAuthorizing = false;
          });
        }
        return;
      }

      final googleAuth = await googleUser.authentication;
      final token = googleAuth.accessToken;

      if (token == null || token.isEmpty) {
        throw Exception('Google Sign-In completed without an access token.');
      }

      if (!mounted) return;

      Navigator.of(context).pop(
        LmsOAuthResult(
          platform: 'google_classroom',
          accessToken: token,
          accountEmail: googleUser.email,
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthorizing = false;
        _errorMessage = 'Google Classroom sign-in failed: ${e.toString().replaceAll("Exception:", "").trim()}';
      });
    }
  }

  Future<void> _handleAuthorizeCanvas() async {
    final token = _canvasTokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your Canvas Personal Access Token.';
      });
      return;
    }

    setState(() {
      _isAuthorizing = true;
    });

    AppFeedback.selection();
    unawaited(HapticFeedback.mediumImpact());

    // Live verification against Canvas API
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://$_cleanedCanvasDomain/api/v1/users/self',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final userData = response.data ?? {};
      final email = userData['primary_email'] as String? ??
          userData['email'] as String? ??
          userData['login_id'] as String? ??
          userData['name'] as String? ??
          'canvas_student@$_cleanedCanvasDomain';

      if (!mounted) return;

      Navigator.of(context).pop(
        LmsOAuthResult(
          platform: 'canvas',
          accessToken: token,
          accountEmail: email,
          canvasDomain: widget.canvasDomain,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthorizing = false;
        if (e.response?.statusCode == 401) {
          _errorMessage = 'Invalid Canvas Access Token. Please verify permissions in Canvas Settings.';
        } else {
          _errorMessage = 'Failed to connect to $_cleanedCanvasDomain: ${e.message}';
        }
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthorizing = false;
        _errorMessage = 'Connection error: $e';
      });
    }
  }

  void _handleDemoSignIn() {
    AppFeedback.light();
    final isCanvas = widget.platform == 'canvas';
    Navigator.of(context).pop(
      LmsOAuthResult(
        platform: widget.platform,
        accessToken: isCanvas ? 'demo_canvas_token' : 'demo_google_classroom_token',
        accountEmail: isCanvas
            ? 'scholar.demo@$_cleanedCanvasDomain'
            : 'scholar.kortexify@gmail.com',
        canvasDomain: widget.canvasDomain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final isCanvas = widget.platform == 'canvas';
    final providerTitle = isCanvas ? 'Canvas LMS' : 'Google Classroom';

    return Dialog(
      backgroundColor: colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.surfaceBorder.withAlpha(120),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withAlpha(isDark ? 60 : 30),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Provider Branding Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.primary.withAlpha(60),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isCanvas ? Icons.view_sidebar_rounded : Icons.class_rounded,
                      color: colors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connect $providerTitle',
                          style: typography.title3.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isCanvas
                              ? _cleanedCanvasDomain
                              : 'Single Sign-On (OAuth 2.0)',
                          style: typography.caption.medium.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Security Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.success.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.success.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 16,
                      color: colors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isCanvas
                            ? 'Encrypted token storage. Read-only access to syllabus and courses.'
                            : l10n.lmsOAuthSecureNotice,
                        style: typography.caption.regular.copyWith(
                          color: colors.success,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.error.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: colors.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: typography.caption.medium.copyWith(
                            color: colors.error,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Canvas Token Input Section
              if (isCanvas) ...[
                const SizedBox(height: 16),
                Text(
                  'Canvas Access Token:',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _canvasTokenController,
                  label: 'Access Token',
                  hintText: 'Paste token from Canvas Settings',
                  isPassword: true,
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Need a token?',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    ShrinkableButton(
                      onTap: _launchCanvasSettings,
                      child: Row(
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 13,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Open Canvas Settings',
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.surfaceTertiary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to generate your Canvas Token:',
                        style: typography.caption.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1. Click "Open Canvas Settings" above.\n'
                        '2. Scroll down to "Approved Integrations".\n'
                        '3. Tap "+ New Access Token" and paste it here.',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 10.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                // Permissions Scope Explanation
                Text(
                  'Permissions Requested:',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ..._requestedScopes.map((scope) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 15,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            scope,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ShrinkableButton(
                      onTap: _isAuthorizing
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.surfaceTertiary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          l10n.lmsCancel,
                          style: typography.callout.medium.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ShrinkableButton(
                      onTap: _isAuthorizing ? null : _handleAuthorize,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary,
                              colors.primary.withAlpha(200),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withAlpha(70),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: _isAuthorizing
                            ? AppLogoLoader(
                                size: 18,
                                color: colors.white,
                              )
                            : Text(
                                isCanvas
                                    ? 'Verify & Connect'
                                    : l10n.lmsAuthorizeAndConnect,
                                style: typography.callout.bold.copyWith(
                                  color: colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),

              // Quick Demo Account fallback button
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: ShrinkableButton(
                    onTap: _isAuthorizing ? null : _handleDemoSignIn,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Test with Demo Account',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary.withAlpha(160),
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
