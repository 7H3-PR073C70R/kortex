import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';

class CollaborativeEditorBadge extends StatelessWidget {
  const CollaborativeEditorBadge({
    required this.editors,
    this.onTap,
    super.key,
  });

  final List<EphemeralParticipant> editors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (editors.isEmpty) return const SizedBox.shrink();

    final theme = context.theme;
    final displayEditors = editors.take(3).toList();
    final overflowCount = editors.length - displayEditors.length;
    final stackWidth =
        (displayEditors.length * 18.0) + (overflowCount > 0 ? 24.0 : 6.0);

    return Semantics(
      container: true,
      label: '${editors.length} active live co-editors on this deck',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.greenAccent.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing live indicator dot
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),

              // Overlapping Avatar Stack
              SizedBox(
                height: 24,
                width: stackWidth,
                child: Stack(
                  children: [
                    for (int i = 0; i < displayEditors.length; i++)
                      Positioned(
                        left: i * 16.0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 1.5,
                            ),
                            gradient: const LinearGradient(
                              colors: [Colors.deepPurple, Colors.indigo],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              displayEditors[i].displayName.isNotEmpty
                                  ? displayEditors[i].displayName[0]
                                        .toUpperCase()
                                  : 'S',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (overflowCount > 0)
                      Positioned(
                        left: displayEditors.length * 16.0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white24,
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '+$overflowCount',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Live Editing',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
