import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Sizing presets for [AppAvatar].
enum AppAvatarSize {
  small(dimension: 32, fontSize: 12, badgeSize: 8),
  medium(dimension: 44, fontSize: 16, badgeSize: 10),
  large(dimension: 64, fontSize: 22, badgeSize: 14),
  extraLarge(dimension: 88, fontSize: 30, badgeSize: 18);

  const AppAvatarSize({
    required this.dimension,
    required this.fontSize,
    required this.badgeSize,
  });

  final double dimension;
  final double fontSize;
  final double badgeSize;
}

/// Accessible circle avatar with network loading, initials, and status badge.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.fallbackIcon,
    this.size = AppAvatarSize.medium,
    this.customDimension,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth = 1.5,
    this.showBadge = false,
    this.badgeColor,
    this.badgeBorderColor,
    this.onTap,
    this.semanticLabel,
  });

  final String? imageUrl;
  final String? name;
  final Widget? fallbackIcon;
  final AppAvatarSize size;
  final double? customDimension;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderWidth;
  final bool showBadge;
  final Color? badgeColor;
  final Color? badgeBorderColor;
  final VoidCallback? onTap;
  final String? semanticLabel;

  double get _dimension => customDimension ?? size.dimension;

  String _getInitials(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final effectiveBg = backgroundColor ?? colors.surfaceTertiary;
    final effectiveFg = foregroundColor ?? colors.primary;
    final effectiveBorder = borderColor ?? colors.surfaceBorder;

    final initials = _getInitials(name);

    Widget content;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      content = Image.network(
        imageUrl!,
        width: _dimension,
        height: _dimension,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallback(
          initials,
          effectiveFg,
          typography,
          colors,
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: effectiveBg,
            alignment: Alignment.center,
            child: SizedBox(
              width: _dimension * 0.4,
              height: _dimension * 0.4,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(effectiveFg),
              ),
            ),
          );
        },
      );
    } else {
      content = _buildFallback(
        initials,
        effectiveFg,
        typography,
        colors,
      );
    }

    final avatarCircle = Container(
      width: _dimension,
      height: _dimension,
      decoration: BoxDecoration(
        color: effectiveBg,
        shape: BoxShape.circle,
        border: Border.all(
          color: effectiveBorder,
          width: borderWidth,
        ),
      ),
      child: ClipOval(
        child: ExcludeSemantics(child: content),
      ),
    );

    Widget avatarWidget = avatarCircle;

    if (showBadge) {
      final badgeDimension = size.badgeSize;
      avatarWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarCircle,
          Positioned(
            right: 0,
            bottom: 0,
            child: ExcludeSemantics(
              child: Container(
                width: badgeDimension,
                height: badgeDimension,
                decoration: BoxDecoration(
                  color: badgeColor ?? colors.success,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: badgeBorderColor ?? colors.surfacePrimary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final userDesc =
        name != null && name!.isNotEmpty ? name! : l10n.defaultUser;
    final defaultImageLabel = showBadge
        ? l10n.profilePictureOfWithStatus(userDesc)
        : l10n.profilePictureOf(userDesc);
    final defaultButtonLabel = showBadge
        ? l10n.viewProfileOfWithStatus(userDesc)
        : l10n.viewProfileOf(userDesc);

    if (onTap != null) {
      return Semantics(
        button: true,
        label: semanticLabel ?? defaultButtonLabel,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Center(child: avatarWidget),
          ),
        ),
      );
    }

    return Semantics(
      image: true,
      label: semanticLabel ?? defaultImageLabel,
      child: avatarWidget,
    );
  }

  Widget _buildFallback(
    String initials,
    Color fgColor,
    TypographyThemeExtension typography,
    AppThemeColorsExtension colors,
  ) {
    if (initials.isNotEmpty) {
      return Center(
        child: Text(
          initials,
          style: typography.subhead.bold.copyWith(
            fontSize: size.fontSize,
            color: fgColor,
          ),
        ),
      );
    }

    return Center(
      child: fallbackIcon ??
          Icon(
            Icons.person_outline,
            size: _dimension * 0.5,
            color: fgColor,
          ),
    );
  }
}
