import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/domain/entities/thought_entry.dart';
import 'package:kortex/src/features/decks/presentation/bloc/focus_session_cubit.dart';
import 'package:kortex/src/features/decks/presentation/bloc/focus_session_state.dart';
import 'package:kortex/src/features/decks/presentation/widgets/deck_sheet_scaffold.dart';

class ThoughtParkingLotSheet extends StatefulWidget {
  const ThoughtParkingLotSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<FocusSessionCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (ctx) => BlocProvider.value(
        value: cubit,
        child: const ThoughtParkingLotSheet(),
      ),
    );
  }

  @override
  State<ThoughtParkingLotSheet> createState() => _ThoughtParkingLotSheetState();
}

class _ThoughtParkingLotSheetState extends State<ThoughtParkingLotSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitThought(FocusSessionCubit cubit) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    unawaited(cubit.parkThought(text));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final cubit = context.read<FocusSessionCubit>();

    return DeckSheetScaffold(
      title: 'Thought Parking Lot',
      subtitle: 'Dump intrusive thoughts in 5s. Clear your working memory.',
      maxWidth: 580,
      maxHeightFactor: 0.8,
      scrollable: false,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.psychology_rounded,
          color: colors.primary,
          size: 20,
        ),
      ),
      children: [
        // Input field
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: typography.body.medium.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Park an intrusive thought...',
                  hintStyle: typography.body.regular.copyWith(
                    color: colors.textMuted,
                  ),
                  filled: true,
                  fillColor: colors.surfaceSecondary,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _submitThought(cubit),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => _submitThought(cubit),
              style: IconButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Thoughts list
        Flexible(
          child: BlocBuilder<FocusSessionCubit, FocusSessionState>(
            builder: (context, state) {
              if (state.parkedThoughts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 40,
                          color: colors.textMuted.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your mind is clear!',
                          style: typography.body.medium.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          'Anything distracting you? Drop it here and resume.',
                          style: typography.footnote.regular.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: state.parkedThoughts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final thought = state.parkedThoughts[index];
                  return _ThoughtListTile(
                    thought: thought,
                    onToggle: () => unawaited(
                      cubit.toggleThoughtResolved(thought.id),
                    ),
                    onDelete: () => unawaited(cubit.deleteThought(thought.id)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ThoughtListTile extends StatelessWidget {
  const _ThoughtListTile({
    required this.thought,
    required this.onToggle,
    required this.onDelete,
  });

  final ThoughtEntry thought;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadius.micro),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                thought.isResolved
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: thought.isResolved ? colors.primary : colors.textMuted,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              thought.content,
              style: typography.body.regular.copyWith(
                color: thought.isResolved
                    ? colors.textMuted
                    : colors.textPrimary,
                decoration: thought.isResolved
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: colors.textMuted,
              size: 18,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
