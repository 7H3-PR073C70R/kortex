import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Modal dialog shown when an uploaded document has already been extracted into a deck.
Future<void> showAlreadyExtractedDialog(
  BuildContext context, {
  required String deckTitle,
  required String deckId,
  required VoidCallback onReExtract,
  String? courseId,
  String? courseCode,
  String? courseTitle,
  DecksRepository? decksRepository,
  DecksBloc? decksBloc,
  DashboardBloc? dashboardBloc,
}) async {
  final colors = context.colors;
  final typography = context.typography;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: context.isDarkMode
          ? colors.surfaceSecondary
          : colors.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.radiusDialog,
        side: BorderSide(color: colors.primary.withAlpha(60)),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.style_rounded,
              color: colors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Document Already Extracted',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        courseId != null
            ? 'We previously extracted this document as "$deckTitle".\n\nWould you like to link it to ${courseCode ?? "this course"}, open the existing deck, or re-extract it from scratch?'
            : 'We previously extracted this document as "$deckTitle".\n\nWould you like to open the existing study deck or re-extract it from scratch?',
        style: typography.callout.regular.copyWith(
          color: colors.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: Text(
            'Cancel',
            style: context.typography.body.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: colors.surfaceBorder),
          ),
          onPressed: () {
            Navigator.of(dialogCtx).pop();
            onReExtract();
          },
          child: Text(context.l10n.ingestionReExtract),
        ),
        if (courseId != null)
          FilledButton.icon(
            icon: const Icon(Icons.link_rounded, size: 16),
            style: FilledButton.styleFrom(
              backgroundColor: colors.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              AppFeedback.medium();
              final repo = decksRepository ??
                  (locator.isRegistered<DecksRepository>()
                      ? locator<DecksRepository>()
                      : null);
              if (repo != null) {
                await repo.linkDeckToCourse(
                  deckId: deckId,
                  courseId: courseId,
                  courseCode: courseCode,
                  subject: courseTitle,
                );
              }
              final dBloc = decksBloc ??
                  (locator.isRegistered<DecksBloc>()
                      ? locator<DecksBloc>()
                      : null);
              dBloc?.add(const DecksRefreshed());

              final dashBloc = dashboardBloc ??
                  (locator.isRegistered<DashboardBloc>()
                      ? locator<DashboardBloc>()
                      : null);
              dashBloc?.add(const DashboardRefreshed());

              if (context.mounted) {
                context.showSnackBar(
                  message:
                      'Linked "$deckTitle" to ${courseCode ?? "Course"}!',
                  type: SnackBarType.success,
                );
                unawaited(
                  context.router.push(StudySessionRoute(deckId: deckId)),
                );
              }
            },
            label: Text('Link to ${courseCode ?? "Course"} & Open'),
          )
        else
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              unawaited(
                context.router.push(StudySessionRoute(deckId: deckId)),
              );
            },
            child: Text('Open "$deckTitle"'),
          ),
      ],
    ),
  );
}
