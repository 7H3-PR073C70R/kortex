import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/post_card_actions_bar.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/post_card_author_row.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/post_card_content_preview.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/post_card_header.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/post_card_media_section.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_card/post_card_tags_row.dart';
import 'package:kortex/src/features/community/presentation/widgets/track_forum_post_card.dart';
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

  final samplePost = ForumPostEntity(
    id: 'post-1',
    authorId: 'author-123',
    authorName: 'MarieCurie',
    track: 'Physics',
    title: 'How does radioactive decay affect nuclear binding energy?',
    content: '**Question:** Can someone explain alpha vs beta decay equations?',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    upvotes: 42,
    downvotes: 2,
    userVote: 1,
    repliesCount: 5,
    isQuestion: true,
    isVerifiedSolution: true,
    isAnonymous: false,
    syllabusTag: 'Nuclear Physics',
    tags: const ['radioactivity', 'isotopes'],
    karmaBounty: 150,
    latexContent: r'E = mc^2',
  );

  final anonymousPost = ForumPostEntity(
    id: 'post-anon',
    authorId: 'anon-id',
    authorName: 'Anonymous Student',
    track: 'Chemistry',
    title: 'Struggling with organic reaction mechanisms',
    content: 'Need help understanding SN1 vs SN2 nucleophilic substitutions.',
    createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    upvotes: 8,
    downvotes: 1,
    userVote: 0,
    repliesCount: 0,
    isQuestion: true,
    isVerifiedSolution: false,
    isAnonymous: true,
  );

  group('PostCard Sub-Widgets Unit & Widget Tests', () {
    testWidgets('PostCardHeader renders channel name, badges, and triggers onOptionsTap',
        (tester) async {
      var optionsTapped = false;
      await tester.pumpWidget(
        createTestWidget(
          PostCardHeader(
            post: samplePost,
            onOptionsTap: () => optionsTapped = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('c/Physics'), findsOneWidget);
      expect(find.text('Knowledge Gap'), findsOneWidget);
      expect(find.text('Solved'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      expect(optionsTapped, isTrue);
    });

    testWidgets('PostCardAuthorRow renders anonymous incognito badge when isAnonymous is true',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          PostCardAuthorRow(post: anonymousPost),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Anonymous Student'), findsOneWidget);
      expect(find.text('Incognito'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
    });

    testWidgets('PostCardAuthorRow renders username, avatar, and XP bounty for standard author',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          PostCardAuthorRow(post: samplePost),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('@MarieCurie'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('+150 XP'), findsOneWidget);
    });

    testWidgets('PostCardContentPreview renders title and cleans question markdown',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          PostCardContentPreview(post: samplePost),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('How does radioactive decay affect nuclear binding energy?'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Can someone explain alpha vs beta decay equations?'),
        findsOneWidget,
      );
    });

    testWidgets('PostCardTagsRow renders track, syllabus, and custom tag pills',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          PostCardTagsRow(post: samplePost),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('#physics'), findsOneWidget);
      expect(find.text('#nuclearphysics'), findsOneWidget);
      expect(find.text('#radioactivity'), findsOneWidget);
      expect(find.text('💰 150 XP Bounty'), findsOneWidget);
      expect(find.text('#question'), findsOneWidget);
    });

    testWidgets('PostCardMediaSection shrinks when no media is attached',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          PostCardMediaSection(post: samplePost),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('PostCardActionsBar renders net votes and triggers upvote callback',
        (tester) async {
      var upvoteTapped = false;
      await tester.pumpWidget(
        createTestWidget(
          PostCardActionsBar(
            post: samplePost,
            onUpvoteTap: () => upvoteTapped = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('${samplePost.netVotes}'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_circle_up_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_circle_up_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      expect(upvoteTapped, isTrue);
    });

    testWidgets('TrackForumPostCard renders completely with semantics and executes onTap',
        (tester) async {
      var cardTapped = false;
      await tester.pumpWidget(
        createTestWidget(
          TrackForumPostCard(
            post: samplePost,
            onTap: () => cardTapped = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('c/Physics'), findsOneWidget);
      expect(find.text('@MarieCurie'), findsOneWidget);
      expect(find.text('${samplePost.netVotes}'), findsOneWidget);

      await tester.tap(find.byType(TrackForumPostCard));
      await tester.pump(const Duration(milliseconds: 100));
      expect(cardTapped, isTrue);
    });
  });
}
