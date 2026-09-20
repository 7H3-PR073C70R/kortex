import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_bloc.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_state.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Unobtrusive floating background ingestion indicator allowing users to
/// navigate and use the entire app freely while document OCR & flashcard
/// synthesis runs in the background.
class BackgroundIngestionIndicator extends HookWidget {
  const BackgroundIngestionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final dismissedDocId = useState<String?>(null);

    return BlocBuilder<IngestionBloc, IngestionState>(
      builder: (context, state) {
        final currentDocId = state.currentDocument?.id ?? '';
        final isDismissed =
            currentDocId.isNotEmpty && dismissedDocId.value == currentDocId;

        final shouldShow =
            !isDismissed && (state.isProcessing || state.isCompleted);

        if (!shouldShow) {
          return const SizedBox.shrink();
        }

        final rawFilename = state.currentDocument?.filename ?? 'Document';
        final isHexOnly = rawFilename.length > 16 &&
            !rawFilename.contains(' ') &&
            !rawFilename.contains('.') &&
            RegExp(r'^[a-fA-F0-9_-]+$').hasMatch(rawFilename);
        final filename = isHexOnly
            ? 'Document (${rawFilename.substring(0, 8)})'
            : rawFilename;
        final isCompleted = state.isCompleted;
        final progress = state.isUploading ? state.uploadProgress : null;

        String statusLabel;
        if (isCompleted) {
          statusLabel = l10n.flashcardsReadyReview;
        } else if (state.isUploading) {
          statusLabel = l10n.uploadingDocStatus(filename);
        } else if (state.isParsingOcr) {
          statusLabel = l10n.parsingOcrDocStatus(filename);
        } else {
          statusLabel = l10n.synthesizingDeckDocStatus(filename);
        }

        return Positioned(
          top: MediaQuery.paddingOf(context).top + 10,
          left: 16,
          right: 16,
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              label: statusLabel,
              button: true,
              child: ShrinkableButton(
                onTap: () {
                  if (isCompleted) {
                    final deck = state.generatedDeck;
                    if (deck != null) {
                      unawaited(
                        context.router.push(
                          GeneratedCardsReviewRoute(
                            documentId: state.currentDocument?.id ?? '',
                            deckTitle: deck.title,
                            subject: deck.subject,
                            initialCards: const [],
                            rawSnippets: state.snippets,
                          ),
                        ),
                      );
                    } else {
                      unawaited(
                        context.router.push(
                          DocumentIngestionRoute(),
                        ),
                      );
                    }
                  } else {
                    unawaited(
                      context.router.push(
                        DocumentIngestionRoute(),
                      ),
                    );
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceSecondary.withAlpha(220)
                            : colors.surfacePrimary.withAlpha(235),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCompleted
                              ? colors.success.withAlpha(160)
                              : colors.primary.withAlpha(140),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isCompleted
                                ? colors.success.withAlpha(35)
                                : colors.primary.withAlpha(35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCompleted
                                      ? colors.success.withAlpha(35)
                                      : colors.primary.withAlpha(35),
                                  border: Border.all(
                                    color: isCompleted
                                        ? colors.success.withAlpha(100)
                                        : colors.primary.withAlpha(80),
                                    width: 1.2,
                                  ),
                                ),
                                child: Center(
                                  child: isCompleted
                                      ? Icon(
                                          Icons.check_circle_rounded,
                                          size: 22,
                                          color: colors.success,
                                        )
                                      : SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            strokeCap: StrokeCap.round,
                                            value: progress,
                                            color: colors.primary,
                                            backgroundColor:
                                                colors.primary.withAlpha(50),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      statusLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: typography.caption.bold.copyWith(
                                        color: colors.textPrimary,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isCompleted
                                          ? l10n.tapToOpenStudyCards
                                          : l10n.processingInBackgroundTap,
                                      style:
                                          typography.footnote.regular.copyWith(
                                        color: colors.textSecondary,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: colors.textSecondary,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                onPressed: () {
                                  dismissedDocId.value = currentDocId;
                                },
                              ),
                            ],
                          ),
                          if (progress != null && !isCompleted) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 3,
                                backgroundColor: colors.surfaceBorder,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
