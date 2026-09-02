import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CameraScannerOverlay extends HookWidget {
  const CameraScannerOverlay({
    required this.onImageCaptured,
    required this.onClose,
    super.key,
  });

  final void Function(String filename, Uint8List bytes) onImageCaptured;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final laserController = useAnimationController(
      duration: const Duration(milliseconds: 2000),
    );

    useEffect(() {
      unawaited(laserController.repeat(reverse: true));
      return null;
    }, [laserController]);

    Future<void> handleCapture() async {
      unawaited(HapticFeedback.heavyImpact());
      try {
        final service = locator.isRegistered<FilePickerService>()
            ? locator<FilePickerService>()
            : FilePickerService();
        final photo = await service.captureCameraPhoto();

        if (photo != null && photo.bytes.isNotEmpty) {
          onImageCaptured(photo.name, photo.bytes);
        }
      } on Object {
        if (context.mounted) {
          context.showSnackBar(
            message: l10n.invalidFileFormatError,
            type: SnackBarType.error,
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Simulated Camera Preview Area
          Center(
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Container(
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.primary.withAlpha(200),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      // Viewfinder Dark background
                      Container(color: Colors.black.withAlpha(150)),

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
                                    Colors.transparent,
                                    colors.syllabotAccent,
                                    Colors.white,
                                    colors.syllabotAccent,
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.syllabotAccent.withAlpha(180),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
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

          // Top Header: Close Button + Title
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: onClose,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.cameraScanTitle,
                    style: typography.title3.bold.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Controls: Instruction + Shutter Button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  l10n.cameraCaptureHint,
                  textAlign: TextAlign.center,
                  style: typography.footnote.medium.copyWith(
                    color: Colors.white.withAlpha(200),
                  ),
                ),
                const SizedBox(height: 24),
                ShrinkableButton(
                  onTap: handleCapture,
                  child: Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
