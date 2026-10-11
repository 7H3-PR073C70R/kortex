import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/services/forum_socratic_hint_service.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_replies_river.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';

/// Coordinator encapsulating pagination, sorting, voting, and real-time operations
/// for forum thread replies.
class ForumThreadRepliesCoordinator {
  const ForumThreadRepliesCoordinator({
    required this.postId,
    required this.repository,
    required this.hubBloc,
    required this.streamUseCase,
    required this.currentPost,
    required this.localReplies,
    required this.sortFilter,
    required this.topLevelOffset,
    required this.isInitialLoadingReplies,
    required this.isLoadingMoreTopLevel,
    required this.hasMoreTopLevel,
    required this.isGeneratingAiHint,
    required this.expandedParentReplyIds,
    required this.loadingParentReplyIds,
    required this.hasMoreSubRepliesMap,
    required this.subReplyOffsets,
  });

  final String postId;
  final CommunityRepository repository;
  final CommunityHubBloc? hubBloc;
  final StreamSyllabotResponseUseCase? streamUseCase;
  final ValueNotifier<ForumPostEntity> currentPost;
  final ValueNotifier<List<ForumReplyEntity>> localReplies;
  final ValueNotifier<ForumSortFilter> sortFilter;
  final ValueNotifier<int> topLevelOffset;
  final ValueNotifier<bool> isInitialLoadingReplies;
  final ValueNotifier<bool> isLoadingMoreTopLevel;
  final ValueNotifier<bool> hasMoreTopLevel;
  final ValueNotifier<bool> isGeneratingAiHint;
  final ValueNotifier<Set<String>> expandedParentReplyIds;
  final ValueNotifier<Set<String>> loadingParentReplyIds;
  final ValueNotifier<Map<String, bool>> hasMoreSubRepliesMap;
  final ValueNotifier<Map<String, int>> subReplyOffsets;

  Future<void> fetchTopLevelReplies({bool isLoadMore = false}) async {
    if (isLoadMore) {
      if (isLoadingMoreTopLevel.value || !hasMoreTopLevel.value) return;
      isLoadingMoreTopLevel.value = true;
    } else {
      if (localReplies.value.isEmpty) {
        isInitialLoadingReplies.value = true;
      }
    }
    final currentOffset = isLoadMore ? topLevelOffset.value : 0;
    const fetchLimit = 15;

    final res = await repository.fetchForumReplies(
      postId: postId,
      topLevelOnly: true,
      offset: currentOffset,
      sortFilter: sortFilter.value.name,
    );

    if (isLoadMore) {
      isLoadingMoreTopLevel.value = false;
    } else {
      isInitialLoadingReplies.value = false;
    }

    res.fold(
      (_) {},
      (fetched) {
        if (isLoadMore) {
          final existingMap = {for (final r in localReplies.value) r.id: r};
          for (final r in fetched) {
            existingMap[r.id] = r;
          }
          localReplies.value = existingMap.values.toList();
          topLevelOffset.value = currentOffset + fetched.length;
          if (fetched.length < fetchLimit) {
            hasMoreTopLevel.value = false;
          }
        } else {
          final childReplies = localReplies.value
              .where(
                (r) => r.parentReplyId != null && r.parentReplyId!.isNotEmpty,
              )
              .toList();
          final combinedMap = {for (final r in fetched) r.id: r};
          for (final c in childReplies) {
            combinedMap[c.id] = c;
          }
          localReplies.value = combinedMap.values.toList();
          topLevelOffset.value = fetched.length;
          hasMoreTopLevel.value = fetched.length >= fetchLimit;
        }
      },
    );
  }

  Future<void> generateSyllabotHint(BuildContext context) async {
    if (isGeneratingAiHint.value) return;
    isGeneratingAiHint.value = true;
    unawaited(HapticFeedback.mediumImpact());
    try {
      final finalHintContent = await ForumSocraticHintService.generateHint(
        post: currentPost.value,
        streamUseCase: streamUseCase,
        onHintGenerated: (hint) =>
            repository.saveForumSocraticHint(postId: postId, hint: hint),
      );

      final res = await repository.replyToForumPost(
        postId: postId,
        content: finalHintContent,
      );
      res.fold(
        (failure) {
          if (context.mounted) {
            context.showSnackBar(
              message: failure.message ?? 'Could not post AI hint.',
              type: SnackBarType.error,
            );
          }
        },
        (reply) {
          if (!localReplies.value.any((r) => r.id == reply.id)) {
            localReplies.value = [...localReplies.value, reply];
          }
          hubBloc?.add(
            ForumPostRepliesIncrementedEvent(
              postId: postId,
              reply: reply,
            ),
          );
        },
      );
    } on Object catch (e) {
      if (context.mounted) {
        context.showSnackBar(
          message: e.toString().replaceFirst('Exception: ', ''),
          type: SnackBarType.error,
        );
      }
    } finally {
      isGeneratingAiHint.value = false;
    }
  }

  Future<void> loadSubRepliesForParent(
    String parentReplyId, {
    bool isLoadMore = false,
  }) async {
    if (loadingParentReplyIds.value.contains(parentReplyId)) return;
    if (isLoadMore && hasMoreSubRepliesMap.value[parentReplyId] == false) {
      return;
    }

    loadingParentReplyIds.value = {
      ...loadingParentReplyIds.value,
      parentReplyId,
    };

    final currentOffset =
        isLoadMore ? (subReplyOffsets.value[parentReplyId] ?? 0) : 0;
    const fetchLimit = 10;

    final res = await repository.fetchForumReplies(
      postId: postId,
      parentReplyId: parentReplyId,
      offset: currentOffset,
    );

    loadingParentReplyIds.value =
        loadingParentReplyIds.value.where((id) => id != parentReplyId).toSet();

    res.fold(
      (_) {},
      (fetched) {
        final existingMap = {for (final r in localReplies.value) r.id: r};
        for (final r in fetched) {
          existingMap[r.id] = r;
        }
        localReplies.value = existingMap.values.toList();
        subReplyOffsets.value = {
          ...subReplyOffsets.value,
          parentReplyId: currentOffset + fetched.length,
        };
        hasMoreSubRepliesMap.value = {
          ...hasMoreSubRepliesMap.value,
          parentReplyId: fetched.length >= fetchLimit,
        };
      },
    );
  }

  void toggleSubRepliesExpansion(String parentReplyId) {
    unawaited(HapticFeedback.selectionClick());
    final isCurrentlyExpanded =
        expandedParentReplyIds.value.contains(parentReplyId);

    if (isCurrentlyExpanded) {
      expandedParentReplyIds.value =
          expandedParentReplyIds.value.where((id) => id != parentReplyId).toSet();
    } else {
      expandedParentReplyIds.value = {
        ...expandedParentReplyIds.value,
        parentReplyId,
      };
      final hasLoadedChildren = localReplies.value.any(
        (r) => r.parentReplyId == parentReplyId,
      );
      if (!hasLoadedChildren) {
        unawaited(loadSubRepliesForParent(parentReplyId));
      }
    }
  }

  void votePost(int direction) {
    final p = currentPost.value;
    final prevVote = p.userVote;
    final newVote = (prevVote == direction) ? 0 : direction;
    var newUpvotes = p.upvotes;
    var newDownvotes = p.downvotes;
    if (prevVote == 1) newUpvotes -= 1;
    if (prevVote == -1) newDownvotes -= 1;
    if (newVote == 1) newUpvotes += 1;
    if (newVote == -1) newDownvotes += 1;
    if (newUpvotes < 0) newUpvotes = 0;
    if (newDownvotes < 0) newDownvotes = 0;

    final updated = p.copyWith(
      upvotes: newUpvotes,
      downvotes: newDownvotes,
      userVote: newVote,
    );
    currentPost.value = updated;
    unawaited(HapticFeedback.selectionClick());

    if (hubBloc != null) {
      hubBloc!.add(
        VoteForumPostEvent(postId: postId, direction: direction),
      );
    } else {
      unawaited(
        repository.voteForumPost(postId: postId, voteDirection: direction),
      );
    }
  }

  void voteReply(ForumReplyEntity targetReply, int direction) {
    final prevVote = targetReply.userVote;
    final newVote = (prevVote == direction) ? 0 : direction;
    var newUpvotes = targetReply.upvotes;
    var newDownvotes = targetReply.downvotes;
    if (prevVote == 1) newUpvotes -= 1;
    if (prevVote == -1) newDownvotes -= 1;
    if (newVote == 1) newUpvotes += 1;
    if (newVote == -1) newDownvotes += 1;
    if (newUpvotes < 0) newUpvotes = 0;
    if (newDownvotes < 0) newDownvotes = 0;

    final updated = targetReply.copyWith(
      upvotes: newUpvotes,
      downvotes: newDownvotes,
      userVote: newVote,
    );

    localReplies.value = localReplies.value
        .map((r) => r.id == targetReply.id ? updated : r)
        .toList();
    unawaited(HapticFeedback.selectionClick());

    if (hubBloc != null) {
      hubBloc!.add(
        VoteForumReplyEvent(
          postId: postId,
          replyId: targetReply.id,
          direction: direction,
        ),
      );
    } else {
      unawaited(
        repository.voteForumReply(
          postId: postId,
          replyId: targetReply.id,
          voteDirection: direction,
        ),
      );
    }
  }

  Future<void> verifySolution(
    BuildContext context,
    ForumReplyEntity reply,
  ) async {
    final res = await repository.verifyForumReply(
      postId: currentPost.value.id,
      replyId: reply.id,
    );
    res.fold(
      (failure) {
        if (context.mounted) {
          context.showSnackBar(
            message: failure.message ?? 'Failed to verify solution',
            type: SnackBarType.error,
          );
        }
      },
      (_) {
        unawaited(HapticFeedback.heavyImpact());
        currentPost.value = currentPost.value.copyWith(
          isVerifiedSolution: true,
        );
        hubBloc?.add(
          VerifyForumReplyEvent(
            postId: currentPost.value.id,
            replyId: reply.id,
          ),
        );
        localReplies.value = localReplies.value
            .map(
              (r) => r.id == reply.id
                  ? r.copyWith(isVerifiedSolution: true)
                  : r,
            )
            .toList();
        if (context.mounted) {
          context.showSnackBar(
            message:
                'Marked as verified solution! ${currentPost.value.karmaBounty > 0 ? currentPost.value.karmaBounty : 100} XP Karma bounty awarded to ${reply.authorName}! 🏆',
            type: SnackBarType.success,
          );
        }
      },
    );
  }
}
