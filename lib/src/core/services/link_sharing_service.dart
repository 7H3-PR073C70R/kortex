import 'dart:async';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/services/dynamic_link_service.dart';
import 'package:share_plus/share_plus.dart';

/// Result object returned by share or copy operations.
class LinkShareResult {
  const LinkShareResult({
    required this.success,
    required this.linkUri,
    this.copiedToClipboard = false,
    this.errorMessage,
  });

  final bool success;
  final Uri linkUri;
  final bool copiedToClipboard;
  final String? errorMessage;
}

/// Helper service for generating Firebase Dynamic Links and seamlessly sharing
/// them via native platform share dialogs or copying to the user's clipboard.
class LinkSharingService {
  LinkSharingService({
    required DynamicLinkService dynamicLinkService,
  }) : _dynamicLinkService = dynamicLinkService;

  final DynamicLinkService _dynamicLinkService;

  /// Share a Flashcard Deck link with title and optional description.
  Future<LinkShareResult> shareDeck({
    required String deckId,
    required String title,
    String? description,
    bool studyMode = false,
  }) async {
    final linkUri = _dynamicLinkService.generateDynamicLink(
      type: DynamicLinkType.deck,
      targetId: deckId,
      parameters: studyMode ? {'mode': 'study'} : null,
      title: title,
      description: description ?? 'Master this deck on Kortexify academic workspace!',
    );

    final shareText =
        '📚 Check out this Flashcard Deck: "$title" on Kortexify!\n$linkUri';

    return _shareOrCopy(
      text: shareText,
      subject: 'Shared Flashcard Deck - $title',
      linkUri: linkUri,
    );
  }

  /// Share a Community Forum discussion thread link.
  Future<LinkShareResult> shareForumPost({
    required String postId,
    required String title,
    String? authorName,
    String? subjectTrack,
  }) async {
    final params = <String, String>{};
    if (authorName != null && authorName.isNotEmpty) {
      params['authorName'] = authorName;
    }
    if (subjectTrack != null && subjectTrack.isNotEmpty) {
      params['track'] = subjectTrack;
    }

    final linkUri = _dynamicLinkService.generateDynamicLink(
      type: DynamicLinkType.forum,
      targetId: postId,
      parameters: params,
      title: title,
      description: 'Join the academic discussion on Kortexify!',
    );

    final shareText =
        '💡 Forum Discussion: "$title"\nJoin the debate on Kortexify: $linkUri';

    return _shareOrCopy(
      text: shareText,
      subject: 'Forum Thread: $title',
      linkUri: linkUri,
    );
  }

  /// Share a Quiz Duel challenge link.
  Future<LinkShareResult> shareQuizDuel({
    required String duelId,
    required String deckId,
    String? deckTitle,
    String? challengerName,
  }) async {
    final params = <String, String>{
      'deckId': deckId,
    };
    if (challengerName != null && challengerName.isNotEmpty) {
      params['challenger'] = challengerName;
    }

    final linkUri = _dynamicLinkService.generateDynamicLink(
      type: DynamicLinkType.quizDuel,
      targetId: duelId,
      parameters: params,
      title: 'Quiz Duel Challenge!',
      description: deckTitle != null ? 'Deck: $deckTitle' : 'Face your peers in real-time!',
    );

    final challengerStr = challengerName != null ? '$challengerName challenged you' : 'You are challenged';
    final shareText =
        '⚔️ $challengerStr to a Quiz Duel${deckTitle != null ? " on $deckTitle" : ""}!\nAccept the challenge here: $linkUri';

    return _shareOrCopy(
      text: shareText,
      subject: 'Quiz Duel Challenge',
      linkUri: linkUri,
    );
  }

  /// Share a Live Virtual Study Room invite link.
  Future<LinkShareResult> shareStudyRoom({
    required String roomId,
    required String roomTitle,
    String? topic,
  }) async {
    final linkUri = _dynamicLinkService.generateDynamicLink(
      type: DynamicLinkType.studyRoom,
      targetId: roomId,
      title: roomTitle,
      description: topic ?? 'Co-working study session',
    );

    final shareText =
        '🎧 Join my Live Study Room: "$roomTitle" on Kortexify!\nCo-work with synchronized Pomodoro timers: $linkUri';

    return _shareOrCopy(
      text: shareText,
      subject: 'Study Room Invitation',
      linkUri: linkUri,
    );
  }

  /// Share a Promo / Referral Code link.
  Future<LinkShareResult> sharePromoCode({
    required String code,
    String? discountText,
  }) async {
    final linkUri = _dynamicLinkService.generateDynamicLink(
      type: DynamicLinkType.promo,
      targetId: code,
      parameters: {'code': code},
      title: 'Kortexify Special Offer',
      description: discountText ?? 'Unlock premium academic features',
    );

    final shareText =
        '🎁 Use my referral code "$code" on Kortexify for ${discountText ?? "special discount"}!\nRedeem here: $linkUri';

    return _shareOrCopy(
      text: shareText,
      subject: 'Kortexify Promo Code',
      linkUri: linkUri,
    );
  }

  /// Copies raw link URI directly to the system clipboard.
  Future<bool> copyLinkToClipboard(Uri linkUri) async {
    try {
      await Clipboard.setData(ClipboardData(text: linkUri.toString()));
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  Future<LinkShareResult> _shareOrCopy({
    required String text,
    required String subject,
    required Uri linkUri,
  }) async {
    try {
      final shareResult = await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject,
        ),
      );

      return LinkShareResult(
        success: shareResult.status != ShareResultStatus.dismissed,
        linkUri: linkUri,
      );
    } on Object catch (e) {
      // Fallback: Copy to clipboard if platform share sheet fails
      final copied = await copyLinkToClipboard(linkUri);
      return LinkShareResult(
        success: copied,
        linkUri: linkUri,
        copiedToClipboard: copied,
        errorMessage: e.toString(),
      );
    }
  }
}
