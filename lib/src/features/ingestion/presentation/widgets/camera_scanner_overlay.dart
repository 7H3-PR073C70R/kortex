import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CameraScannerOverlay extends HookWidget {
  const CameraScannerOverlay({
    required this.onImagesCaptured,
    required this.onClose,
    super.key,
  });

  final void Function(List<PickedDocument> images) onImagesCaptured;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final laserController = useAnimationController(
      duration: const Duration(milliseconds: 2000),
    );

    final capturedPhotos = useState<List<PickedDocument>>([]);
    final isCapturing = useState<bool>(false);
    final cameraControllerState = useState<CameraController?>(null);
    final isCameraInitialized = useState<bool>(false);

    useEffect(() {
      unawaited(laserController.repeat(reverse: true));
      return null;
    }, [laserController]);

    useEffect(() {
      var isMounted = true;
      CameraController? controller;

      Future<void> initCamera() async {
        try {
          final cameras = await availableCameras();
          if (cameras.isEmpty) return;

          final backCamera = cameras.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );

          controller = CameraController(
            backCamera,
            ResolutionPreset.high,
            enableAudio: false,
          );

          await controller!.initialize();
          if (isMounted) {
            cameraControllerState.value = controller;
            isCameraInitialized.value = true;
          }
        } on Object catch (_) {
          // Fallback to FilePickerService image_picker if live camera fails to initialize
        }
      }

      unawaited(initCamera());

      return () {
        isMounted = false;
        unawaited(controller?.dispose());
      };
    }, []);

    FilePickerService getService() {
      return locator.isRegistered<FilePickerService>()
          ? locator<FilePickerService>()
          : FilePickerService();
    }

    Future<void> handleCapture() async {
      if (isCapturing.value) return;
      isCapturing.value = true;
      unawaited(HapticFeedback.heavyImpact());

      try {
        PickedDocument? photo;
        final controller = cameraControllerState.value;

        if (controller != null && controller.value.isInitialized) {
          final xFile = await controller.takePicture();
          final bytes = await xFile.readAsBytes();
          final ext = xFile.name.split('.').last.toLowerCase();
          photo = PickedDocument(
            name: xFile.name,
            extension: ext.isNotEmpty ? ext : 'jpg',
            bytes: bytes,
            path: xFile.path,
          );
        } else {
          photo = await getService().captureCameraPhoto();
        }

        if (photo != null && photo.bytes.isNotEmpty) {
          capturedPhotos.value = [...capturedPhotos.value, photo];
        }
      } on Object {
        if (context.mounted) {
          context.showSnackBar(
            message: l10n.invalidFileFormatError,
            type: SnackBarType.error,
          );
        }
      } finally {
        isCapturing.value = false;
      }
    }

    Future<void> handleGalleryPick() async {
      if (isCapturing.value) return;
      isCapturing.value = true;
      unawaited(HapticFeedback.lightImpact());

      try {
        final photos = await getService().pickMultipleImagesFromGallery();
        if (photos.isNotEmpty) {
          capturedPhotos.value = [...capturedPhotos.value, ...photos];
        }
      } on Object {
        if (context.mounted) {
          context.showSnackBar(
            message: l10n.invalidFileFormatError,
            type: SnackBarType.error,
          );
        }
      } finally {
        isCapturing.value = false;
      }
    }

    void handleRemovePhoto(int index) {
      final updated = List<PickedDocument>.from(capturedPhotos.value);
      if (index >= 0 && index < updated.length) {
        updated.removeAt(index);
        capturedPhotos.value = updated;
      }
    }

    void handleDone() {
      if (capturedPhotos.value.isNotEmpty) {
        onImagesCaptured(capturedPhotos.value);
      }
    }

    return Scaffold(
      backgroundColor: colors.black,
      body: Stack(
        children: [
          // Live Camera Stream Background
          if (isCameraInitialized.value &&
              cameraControllerState.value != null &&
              cameraControllerState.value!.value.isInitialized)
            Positioned.fill(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width:
                        cameraControllerState
                            .value!
                            .value
                            .previewSize
                            ?.height ??
                        1,
                    height:
                        cameraControllerState.value!.value.previewSize?.width ??
                        1,
                    child: CameraPreview(cameraControllerState.value!),
                  ),
                ),
              ),
            ),

          // Dark overlay tint
          Positioned.fill(
            child: Container(
              color: colors.black.withAlpha(140),
            ),
          ),

          // Clear See-Through Camera Viewfinder Target Area
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.panel),
                    border: Border.all(
                      color: colors.primary.withAlpha(220),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withAlpha(40),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.panel - 2),
                    child: Stack(
                      children: [
                        // Viewfinder Transparent Window
                        Container(color: colors.transparent),

                        // Animated Laser Scan Line
                        AnimatedBuilder(
                          animation: laserController,
                          builder: (context, child) {
                            return Align(
                              alignment: Alignment(
                                0,
                                (laserController.value * 2.0) - 1.0,
                              ),
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colors.transparent,
                                      colors.syllabotAccent,
                                      colors.white,
                                      colors.syllabotAccent,
                                      colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Corner markers
                        Positioned(
                          top: 16,
                          left: 16,
                          child: _CornerBracket(color: colors.primary),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Transform.rotate(
                            angle: 1.5708,
                            child: _CornerBracket(color: colors.primary),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: Transform.rotate(
                            angle: -1.5708,
                            child: _CornerBracket(color: colors.primary),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Transform.rotate(
                            angle: 3.14159,
                            child: _CornerBracket(color: colors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top Header: Close Button + Title + Page Count Badge
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return AnimatedContainer(
                            duration: AppMotion.snappy,
                            curve: AppMotion.easeOutCubic,
                            decoration: BoxDecoration(
                              color: isHovered
                                  ? colors.white.withAlpha(30)
                                  : colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: colors.white,
                                size: 26,
                              ),
                              onPressed: onClose,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.cameraScanTitle,
                        style: typography.title3.bold.copyWith(
                          color: colors.white,
                        ),
                      ),
                      const Spacer(),
                      if (capturedPhotos.value.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            '${capturedPhotos.value.length} Page${capturedPhotos.value.length > 1 ? "s" : ""} Captured',
                            style: typography.caption.bold.copyWith(
                              color: colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Controls: Captured Thumbnail Reel + Action Buttons
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Horizontal Thumbnail Preview Reel
                    if (capturedPhotos.value.isNotEmpty) ...[
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          scrollDirection: Axis.horizontal,
                          itemCount: capturedPhotos.value.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final doc = capturedPhotos.value[index];
                            return Stack(
                              children: [
                                Container(
                                  width: 60,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: colors.primary,
                                      width: 2,
                                    ),
                                    image: DecorationImage(
                                      image: MemoryImage(doc.bytes),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () => handleRemovePhoto(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: colors.black.withAlpha(200),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 14,
                                        color: colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Text(
                      capturedPhotos.value.isEmpty
                          ? l10n.cameraCaptureHint
                          : 'Snap another page or tap Process to generate flashcards',
                      textAlign: TextAlign.center,
                      style: typography.footnote.medium.copyWith(
                        color: colors.white.withAlpha(200),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Controls Row: Gallery Import | Capture Shutter | Process Batch
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Gallery Multi-Pick Button
                          PlatformHoverBuilder(
                            builder: (context, isHovered, child) {
                              return AnimatedScale(
                                scale: isHovered ? 1.08 : 1.0,
                                duration: AppMotion.snappy,
                                curve: AppMotion.easeOutCubic,
                                child: InkWell(
                                  onTap: handleGalleryPick,
                                  borderRadius: BorderRadius.circular(AppRadius.card),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: colors.white.withAlpha(30),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colors.white.withAlpha(60),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.photo_library_outlined,
                                      color: colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Central Camera Shutter Button
                          PlatformHoverBuilder(
                            builder: (context, isHovered, child) {
                              return AnimatedScale(
                                scale: isHovered ? 1.06 : 1.0,
                                duration: AppMotion.snappy,
                                curve: AppMotion.easeOutCubic,
                                child: ShrinkableButton(
                                  onTap: handleCapture,
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colors.white,
                                        width: 4,
                                      ),
                                      boxShadow: isHovered
                                          ? [
                                              BoxShadow(
                                                color: colors.black.withAlpha(80),
                                                blurRadius: 16,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colors.primary,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.camera_alt_rounded,
                                          color: colors.white,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Process Batch / Done Button
                          if (capturedPhotos.value.isNotEmpty)
                            PlatformHoverBuilder(
                              builder: (context, isHovered, child) {
                                return AnimatedScale(
                                  scale: isHovered ? 1.06 : 1.0,
                                  duration: AppMotion.snappy,
                                  curve: AppMotion.easeOutCubic,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colors.success,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.card,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Process (${capturedPhotos.value.length})',
                                      style: typography.footnote.bold,
                                    ),
                                    onPressed: handleDone,
                                  ),
                                );
                              },
                            )
                          else
                            const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _CornerPainter(color: color),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
