import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class AudioInputWaveformButton extends HookWidget {
  const AudioInputWaveformButton({
    required this.onTranscriptionResult,
    super.key,
  });

  final ValueChanged<String> onTranscriptionResult;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isRecording = useState<bool>(false);

    final pulseController = useAnimationController(
      duration: const Duration(milliseconds: 1000),
    );

    useEffect(() {
      if (isRecording.value) {
        unawaited(pulseController.repeat(reverse: true));
      } else {
        pulseController
          ..stop()
          ..reset();
      }
      return null;
    }, [isRecording.value]);

    void toggleRecording() {
      unawaited(HapticFeedback.mediumImpact());
      if (!isRecording.value) {
        isRecording.value = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.mic, color: colors.error, size: 18),
                const SizedBox(width: 8),
                Text(l10n.voiceInputListening),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );

        // Simulate voice transcription completion after 2.5s
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (isRecording.value) {
            isRecording.value = false;
            onTranscriptionResult(
              "Derive the Euler-Lagrange equation from Hamilton's principle",
            );
          }
        });
      } else {
        isRecording.value = false;
      }
    }

    return ShrinkableButton(
      onTap: toggleRecording,
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (context, child) {
          final scale =
              isRecording.value ? 1.0 + (pulseController.value * 0.15) : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording.value
                    ? colors.error.withAlpha(isDark ? 180 : 220)
                    : colors.primary.withAlpha(isDark ? 50 : 25),
                border: Border.all(
                  color: isRecording.value
                      ? colors.error
                      : colors.primary.withAlpha(isDark ? 100 : 60),
                ),
              ),
              child: Center(
                child: isRecording.value
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final h = 6.0 +
                              (math.sin(
                                    pulseController.value * math.pi + (i * 1.2),
                                  ) *
                                  8)
                                  .abs();
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 2.5,
                            height: h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      )
                    : Icon(
                        Icons.mic_none_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
