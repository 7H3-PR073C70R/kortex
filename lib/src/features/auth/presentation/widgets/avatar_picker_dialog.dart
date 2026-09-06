import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_avatar_use_case.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Interactive modal sheet to pick photos from camera/gallery, select scholar emojis,
/// or apply remote avatar links.
void showAvatarPickerDialog(
  BuildContext context,
  AppThemeColorsExtension colors,
  TypographyThemeExtension typography,
) {
  AppFeedback.selection();
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
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: colors.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customize Profile Avatar',
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 17,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Upload a photo from your device or pick a scholar avatar',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),

            // 1. Device Photo Picker Buttons (Gallery & Camera)
            Row(
              children: [
                Expanded(
                  child: ShrinkableButton(
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _pickAndUploadPhoto(context, ImageSource.gallery);
                    },
                    child: Container(
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
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withAlpha(50),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
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
                            'Choose Photo',
                            style: typography.caption.bold.copyWith(
                              color: colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ShrinkableButton(
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _pickAndUploadPhoto(context, ImageSource.camera);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.primary.withAlpha(80),
                          width: 1.2,
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
                            'Take Photo',
                            style: typography.caption.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: colors.surfaceBorder.withAlpha(70)),
            const SizedBox(height: 14),

            Text(
              'Or Select an Avatar Icon',
              style: typography.body.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 13,
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
                return ShrinkableButton(
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _persistPhotoUrl(context, item['id']!);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.surfaceSecondary,
                          border: Border.all(
                            color: colors.surfaceBorder.withAlpha(120),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.black.withAlpha(
                                context.isDarkMode ? 40 : 15,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            item['emoji']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['label']!,
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                          fontSize: 10.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: colors.surfaceBorder.withAlpha(70)),
            const SizedBox(height: 12),

            // Custom Photo URL Input
            Text(
              'Or Web Photo Link',
              style: typography.body.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: urlController,
                    hintText: 'https://example.com/photo.jpg',
                  ),
                ),
                const SizedBox(width: 8),
                ShrinkableButton(
                  onTap: () async {
                    final url = urlController.text.trim();
                    if (url.isNotEmpty) {
                      Navigator.of(ctx).pop();
                      await _persistPhotoUrl(context, url);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Apply',
                      style: typography.caption.bold.copyWith(
                        color: colors.white,
                        fontSize: 12.5,
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
}

Future<void> _pickAndUploadPhoto(
  BuildContext context,
  ImageSource source,
) async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    if (context.mounted) {
      await _persistPhotoUrl(context, base64String);
    }
  } on Object catch (e) {
    if (context.mounted) {
      context.showSnackBar(
        message: 'Could not select photo: $e',
        type: SnackBarType.error,
      );
    }
  }
}

Future<void> _persistPhotoUrl(BuildContext context, String photoUrl) async {
  AppFeedback.light();
  // 1. Immediately reflect the change in local AuthBloc state
  context.read<AuthBloc>().add(AuthAvatarUpdated(photoUrl));

  // 2. Persist to cloud repository
  final result = await locator<UpdateAvatarUseCase>()(photoUrl);
  result.fold(
    (failure) {
      if (context.mounted) {
        context.showSnackBar(
          message: 'Could not sync avatar: ${failure.message}',
          type: SnackBarType.error,
        );
      }
    },
    (_) {
      if (context.mounted) {
        context.read<AuthBloc>().add(const AuthProfileFetchRequested());
        context.showSnackBar(
          message: 'Avatar updated successfully!',
          type: SnackBarType.success,
        );
      }
    },
  );
}
