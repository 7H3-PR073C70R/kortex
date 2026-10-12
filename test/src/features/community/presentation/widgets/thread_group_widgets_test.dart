import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/discussion_thread_group_card.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  final sampleParentReply = ForumReplyEntity(
    id: 'reply-1',
    postId: 'post-100',
    authorId: 'user-author',
    authorName: 'Ada Lovelace',
    content: 'This is a verified solution explaining heat engines and entropy.',
    createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
    upvotes: 12,
    downvotes: 0,
    userVote: 1,
    repliesCount: 2,
    isVerifiedSolution: true,
  );

  final sampleChildReply = ForumReplyEntity(
    id: 'reply-child-1',
    postId: 'post-100',
    parentReplyId: 'reply-1',
    authorId: 'user-student',
    authorName: 'StudentDev',
    content: 'Thanks for the explanation! What about the Carnot efficiency?',
    createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
    upvotes: 3,
    downvotes: 0,
    userVote: 0,
    repliesCount: 0,
  );

  group('Thread Group Sub-Widgets Unit & Widget Tests', () {
    testWidgets('ParentReplyAuthorHeader renders author, time, and scholar badge',
        (tester) async {
      var editCalled = false;
      await tester.pumpWidget(
        createTestWidget(
          ParentReplyAuthorHeader(
            parentReply: sampleParentReply,
            isAiReply: false,
            isOp: false,
            onEditReply: () => editCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@Ada Lovelace'), findsOneWidget);
      expect(find.text('Scholar'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('ParentReplyContentBody renders clean content text',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          ParentReplyContentBody(
            parentReply: sampleParentReply,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('This is a verified solution explaining heat engines'),
        findsOneWidget,
      );
    });

    testWidgets('ForumReplyActionsBar renders vote count, reply, and flashcard triggers',
        (tester) async {
      var upvoteTapped = false;
      var replyTapped = false;
      var flashcardTapped = false;

      await tester.pumpWidget(
        createTestWidget(
          ForumReplyActionsBar(
            parentReply: sampleParentReply,
            isUpvoted: true,
            isDownvoted: false,
            onVote: (dir) => upvoteTapped = dir == 1,
            onReplyTap: () => replyTapped = true,
            totalChildCount: 2,
            isQuestion: true,
            hasVerifiedSolution: true,
            isAuthor: false,
            onVerifySolution: () {},
            onSaveFlashcard: (_) => flashcardTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+12'), findsOneWidget);
      expect(find.text('Reply (2)'), findsOneWidget);
      expect(find.text('Save Flashcard'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
      expect(upvoteTapped, isTrue);

      await tester.tap(find.text('Reply (2)'));
      expect(replyTapped, isTrue);

      await tester.tap(find.text('Save Flashcard'));
      expect(flashcardTapped, isTrue);
    });

    testWidgets('ForumReplyChildrenSpine renders collapsed badge and expands on tap',
        (tester) async {
      var toggleExpandCalled = false;

      await tester.pumpWidget(
        createTestWidget(
          ForumReplyChildrenSpine(
            totalChildCount: 2,
            children: [sampleChildReply],
            isExpanded: false,
            isLoadingChildren: false,
            hasMoreChildren: false,
            opAuthorName: 'OriginalPoster',
            onToggleExpand: () => toggleExpandCalled = true,
            onLoadMoreChildren: () {},
            onChildVote: (_, __) {},
            onChildReplyTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@StudentDev'), findsOneWidget);
      expect(find.text('• View 2 replies'), findsOneWidget);

      await tester.tap(find.text('• View 2 replies'));
      expect(toggleExpandCalled, isTrue);
    });

    testWidgets('ForumReplyChildrenSpine renders expanded children stream and collapse trigger',
        (tester) async {
      var toggleCollapseCalled = false;

      await tester.pumpWidget(
        createTestWidget(
          ForumReplyChildrenSpine(
            totalChildCount: 1,
            children: [sampleChildReply],
            isExpanded: true,
            isLoadingChildren: false,
            hasMoreChildren: false,
            opAuthorName: 'OriginalPoster',
            onToggleExpand: () => toggleCollapseCalled = true,
            onLoadMoreChildren: () {},
            onChildVote: (_, __) {},
            onChildReplyTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@StudentDev'), findsOneWidget);
      expect(find.text('Collapse replies'), findsOneWidget);

      await tester.tap(find.text('Collapse replies'));
      expect(toggleCollapseCalled, isTrue);
    });

    testWidgets('Level2ChildReplyCard renders nested reply, vote pill, and collapses on toggle',
        (tester) async {
      var childVoted = false;
      var childReplyTapped = false;

      await tester.pumpWidget(
        createTestWidget(
          Level2ChildReplyCard(
            childReply: sampleChildReply,
            opAuthorName: 'OriginalPoster',
            onVote: (dir) => childVoted = true,
            onReplyTap: () => childReplyTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@StudentDev'), findsOneWidget);
      expect(
        find.textContaining('What about the Carnot efficiency?'),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
      expect(childVoted, isTrue);

      await tester.tap(find.text('Reply'));
      expect(childReplyTapped, isTrue);

      // Collapse child
      await tester.tap(find.byIcon(Icons.unfold_less_rounded));
      await tester.pumpAndSettle();

      expect(find.text('• Collapsed comment'), findsOneWidget);
    });

    testWidgets('DiscussionThreadGroupCard integrates parent card and child replies',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          DiscussionThreadGroupCard(
            parentReply: sampleParentReply,
            children: [sampleChildReply],
            opAuthorName: 'OriginalPoster',
            isQuestion: true,
            isAuthor: false,
            hasVerifiedSolution: true,
            isExpanded: true,
            isLoadingChildren: false,
            hasMoreChildren: false,
            onToggleExpand: () {},
            onLoadMoreChildren: () {},
            onVote: (_) {},
            onChildVote: (_, __) {},
            onReplyTap: () {},
            onChildReplyTap: (_) {},
            onVerifySolution: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@Ada Lovelace'), findsOneWidget);
      expect(find.text('@StudentDev'), findsOneWidget);
      expect(find.text('+12'), findsOneWidget);
    });
  });
}
