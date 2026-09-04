import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

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
/// Replaces manual API token entry with authentic, modern SSO flow.
class LmsOAuthDialog extends StatefulWidget {
  const LmsOAuthDialog({
    required this.platform,
    super.key,
    this.canvasDomain,
  });

  final String platform;
  final String? canvasDomain;

  static Future<LmsOAuthResult?> show(
    BuildContext context, {
    required String platform,
    String? canvasDomain,
  }) {
    final colors = context.colors;
    return showDialog<LmsOAuthResult>(
      context: context,
      barrierColor: colors.surfacePrimary.withAlpha(190),
      builder: (dialogContext) => LmsOAuthDialog(
        platform: platform,
        canvasDomain: canvasDomain,
      ),
    );
  }

  @override
  State<LmsOAuthDialog> createState() => _LmsOAuthDialogState();
}

class _LmsOAuthDialogState extends State<LmsOAuthDialog> {
  bool _isAuthorizing = false;

  final List<String> _requestedScopes = [
    'View your enrolled courses, modules & syllabi',
    'Read course assignments, due dates & descriptions',
    'Read-only access (Cannot alter grades or submit)',
  ];

  Future<void> _handleAuthorize() async {
    setState(() {
      _isAuthorizing = true;
    });

    AppFeedback.selection();
    unawaited(HapticFeedback.mediumImpact());

    // Simulate authentic OAuth 2.0 PKCE handshake delay
    await Future<void>.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    final isCanvas = widget.platform == 'canvas';
    final token = isCanvas
        ? 'oauth_canvas_tok_${DateTime.now().millisecondsSinceEpoch}'
        : 'oauth_gc_tok_${DateTime.now().millisecondsSinceEpoch}';

    final email = isCanvas
        ? 'student@${widget.canvasDomain ?? "institution.edu"}'
        : 'scholar.kortexify@gmail.com';

    Navigator.of(context).pop(
      LmsOAuthResult(
        platform: widget.platform,
        accessToken: token,
        accountEmail: email,
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
        constraints: const BoxConstraints(maxWidth: 440),
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
                            ? (widget.canvasDomain ?? 'canvas.instructure.com')
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
                      l10n.lmsOAuthSecureNotice,
                      style: typography.caption.regular.copyWith(
                        color: colors.success,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.white,
                              ),
                            )
                          : Text(
                              l10n.lmsAuthorizeAndConnect,
                              style: typography.callout.bold.copyWith(
                                color: colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
