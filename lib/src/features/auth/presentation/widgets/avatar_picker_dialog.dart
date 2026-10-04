import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_avatar_use_case.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Interactive modal sheet to pick photos from camera/gallery, select scholar emojis,
/// or apply remote avatar links. Clamped for desktop/tablet workstations with
/// organic hover motion and concentric radii.
void showAvatarPickerDialog(
  BuildContext context,
  AppThemeColorsExtension colors,
  TypographyThemeExtension typography,
) {
  AppFeedback.selection();
  final l10n = context.l10n;
  final urlController = TextEditingController();

  final avatars = [
    {'emoji': '🎓', 'label': 'Scholar', 'id': 'emoji:🎓'},
    {'emoji': '📚', 'label': 'Academic', 'id': 'emoji:📚'},
    {'emoji': '💡', 'label': 'Innovator', 'id': 'emoji:💡'},
    {'emoji': '🎨', 'label': 'Creative', 'id': 'emoji:🎨'},
    {'emoji': '🏛️', 'label': 'Law', 'id': 'emoji:🏛️'},
    {'emoji': '🩺', 'label': 'Medical', 'id': 'emoji:🩺'},
    {'emoji': '💼', 'label': 'Business', 'id': 'emoji:💼'},
    {'emoji': '🧪', 'label': 'Science', 'id': 'emoji:🧪'},
    {'emoji': '🌍', 'label': 'Humanities', 'id': 'emoji:🌍'},
    {'emoji': '📝', 'label': 'Author', 'id': 'emoji:📝'},
  ];

  unawaited(
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: colors.surfacePrimary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.dialog),
              ),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(90),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.surfaceBorder,
                      borderRadius: AppRadius.radiusMicro,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.authAvatarPickerTitle,
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    PlatformHoverBuilder(
                      builder: (context, isHovered, child) {
                        return IconButton(
                          icon: AnimatedContainer(
                            duration: AppMotion.snappy,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isHovered
                                  ? colors.surfaceBorder.withAlpha(40)
                                  : colors.transparent,
                              borderRadius: AppRadius.radiusMicro,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: colors.textSecondary,
                              size: 20,
                            ),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.authAvatarPickerSubtitle,
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),

                // 1. Device Photo Picker Buttons (Gallery & Camera)
                Row(
                  children: [
                    Expanded(
                      child: PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return ShrinkableButton(
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              await _pickAndUploadPhoto(
                                context,
                                ImageSource.gallery,
                              );
                            },
                            child: AnimatedContainer(
                              duration: AppMotion.snappy,
                              curve: AppMotion.easeOutCubic,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colors.primary,
                                    colors.syllabotAccent,
                                  ],
                                ),
                                borderRadius: AppRadius.radiusCard,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.black.withAlpha(
                                      isHovered ? 50 : 25,
                                    ),
                                    blurRadius: isHovered ? 10 : 6,
                                    offset: Offset(0, isHovered ? 3 : 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.photo_library_rounded,
                                    color: colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.authAvatarPickerChooseGallery,
                                    style: typography.caption.bold.copyWith(
                                      color: colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return ShrinkableButton(
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              await _pickAndUploadPhoto(
                                context,
                                ImageSource.camera,
                              );
                            },
                            child: AnimatedContainer(
                              duration: AppMotion.snappy,
                              curve: AppMotion.easeOutCubic,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isHovered
                                    ? colors.surfaceSecondary.withAlpha(220)
                                    : colors.surfaceSecondary,
                                borderRadius: AppRadius.radiusCard,
                                border: Border.all(
                                  color: isHovered
                                      ? colors.primary
                                      : colors.primary.withAlpha(80),
                                  width: isHovered ? 1.5 : 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt_rounded,
                                    color: colors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.authAvatarPickerTakeCamera,
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(height: 1, color: colors.surfaceBorder.withAlpha(70)),
                const SizedBox(height: 14),

                Text(
                  l10n.authAvatarPickerEmojiSection,
                  style: typography.body.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Aesthetic Avatar Tokens Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: avatars.length,
                  itemBuilder: (context, index) {
                    final item = avatars[index];
                    return PlatformHoverBuilder(
                      builder: (context, isHovered, child) {
                        return ShrinkableButton(
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            await _persistPhotoUrl(context, item['id']!);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedScale(
                                scale: isHovered ? 1.08 : 1.0,
                                duration: AppMotion.snappy,
                                curve: AppMotion.easeOutCubic,
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isHovered
                                        ? colors.surfaceSecondary.withAlpha(240)
                                        : colors.surfaceSecondary,
                                    border: Border.all(
                                      color: isHovered
                                          ? colors.primary
                                          : colors.surfaceBorder.withAlpha(120),
                                      width: isHovered ? 1.8 : 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.black.withAlpha(
                                          context.isDarkMode
                                              ? (isHovered ? 50 : 25)
                                              : (isHovered ? 20 : 10),
                                        ),
                                        blurRadius: isHovered ? 10 : 6,
                                        offset: Offset(0, isHovered ? 3 : 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      item['emoji']!,
                                      textAlign: TextAlign.center,
                                      style: typography.title1.regular.copyWith(
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item['label']!,
                                style: typography.caption.medium.copyWith(
                                  color: isHovered
                                      ? colors.primary
                                      : colors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: colors.surfaceBorder.withAlpha(70)),
                const SizedBox(height: 12),

                // Custom Photo URL Input
                Text(
                  l10n.authAvatarPickerUrlSection,
                  style: typography.body.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: urlController,
                        hintText: l10n.authAvatarPickerUrlHint,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PlatformHoverBuilder(
                      builder: (context, isHovered, child) {
                        return ShrinkableButton(
                          onTap: () async {
                            final url = urlController.text.trim();
                            if (url.isNotEmpty) {
                              Navigator.of(ctx).pop();
                              await _persistPhotoUrl(context, url);
                            }
                          },
                          child: AnimatedContainer(
                            duration: AppMotion.snappy,
                            curve: AppMotion.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isHovered
                                  ? colors.primary.withAlpha(230)
                                  : colors.primary,
                              borderRadius: AppRadius.radiusCard,
                              boxShadow: [
                                BoxShadow(
                                  color: colors.black.withAlpha(
                                    isHovered ? 50 : 25,
                                  ),
                                  blurRadius: isHovered ? 10 : 6,
                                  offset: Offset(0, isHovered ? 3 : 2),
                                ),
                              ],
                            ),
                            child: Text(
                              l10n.authAvatarPickerApplyUrl,
                              style: typography.caption.bold.copyWith(
                                color: colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pickAndUploadPhoto(
  BuildContext context,
  ImageSource source,
) async {
  final l10n = context.l10n;
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 75,
    );
    if (picked == null) return;

    var bytes = await picked.readAsBytes();
    // Enforce <200KB payload limit on client side
    if (bytes.length > 200 * 1024) {
      bytes = bytes.sublist(0, 200 * 1024);
    }

    if (context.mounted) {
      final confirmedBytes = await _showImageCropperPreviewModal(context, bytes);
      if (confirmedBytes != null && context.mounted) {
        final base64String = 'data:image/jpeg;base64,${base64Encode(confirmedBytes)}';
        await _persistPhotoUrl(context, base64String);
      }
    }
  } on Object catch (e) {
    if (context.mounted) {
      context.showSnackBar(
        message: l10n.authAvatarPickerPhotoError(e.toString()),
        type: SnackBarType.error,
      );
    }
  }
}

Future<Uint8List?> _showImageCropperPreviewModal(
  BuildContext context,
  Uint8List imageBytes,
) async {
  final colors = context.colors;
  final typography = context.typography;
  final isDark = context.isDarkMode;

  return showModalBottomSheet<Uint8List?>(
    context: context,
    backgroundColor: colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.surfacePrimary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.dialog),
              ),
              border: Border.all(color: colors.surfaceBorder.withAlpha(90)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.surfaceBorder,
                    borderRadius: AppRadius.radiusMicro,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Crop & Align Avatar',
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Preview your profile photo alignment before saving.',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),

                // Circular Crop Frame Preview
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.primary,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 60 : 20),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          'Cancel',
                          style: typography.body.bold.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShrinkableButton(
                        onTap: () {
                          AppFeedback.correct();
                          Navigator.of(ctx).pop(imageBytes);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colors.primary, colors.syllabotAccent],
                            ),
                            borderRadius: AppRadius.radiusPanel,
                          ),
                          child: Center(
                            child: Text(
                              'Apply Avatar',
                              style: typography.body.bold.copyWith(
                                color: colors.white,
                                fontSize: 14,
                              ),
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
        ),
      );
    },
  );
}

Future<void> _persistPhotoUrl(BuildContext context, String photoUrl) async {
  final l10n = context.l10n;
  AppFeedback.light();
  // 1. Immediately reflect the change in local AuthBloc state
  context.read<AuthBloc>().add(AuthAvatarUpdated(photoUrl));

  // 2. Persist to cloud repository
  final result = await locator<UpdateAvatarUseCase>()(photoUrl);
  result.fold(
    (failure) {
      if (context.mounted) {
        context.showSnackBar(
          message: l10n.authAvatarPickerSyncError(failure.message ?? ''),
          type: SnackBarType.error,
        );
      }
    },
    (_) {
      if (context.mounted) {
        context.read<AuthBloc>().add(const AuthProfileFetchRequested());
        context.showSnackBar(
          message: l10n.authAvatarPickerSuccess,
          type: SnackBarType.success,
        );
      }
    },
  );
}
