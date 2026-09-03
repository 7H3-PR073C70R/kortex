import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';
import 'package:kortex/src/features/community/presentation/bloc/auto_community_cubit.dart';
import 'package:kortex/src/features/community/presentation/bloc/auto_community_state.dart';
import 'package:kortex/src/features/community/presentation/widgets/auto_community_banner_widget.dart';
import 'package:kortex/src/features/community/presentation/widgets/quick_join_room_chip.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';

class MockAutoCommunityCubit extends Mock implements AutoCommunityCubit {}

void main() {
  group('AutoCommunityBannerWidget & QuickJoinRoomChip UI Test Suite', () {
    late MockAutoCommunityCubit mockCubit;

    const tCommunity = StudyCommunityEntity(
      id: 'comm_waec_bio',
      courseCode: 'WAEC-BIO',
      title: 'WAEC Biology Hub',
      department: 'Science',
      memberCount: 56,
      activeRoomsCount: 1,
      forumThreadsCount: 4,
      isFoundingMember: true,
      activeRoomId: 'room_bio_pomodoro',
      activeRoomTitle: 'Genetics 25m Focus',
    );

    setUp(() {
      mockCubit = MockAutoCommunityCubit();
    });

    Widget createTestApp(Widget child) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<AutoCommunityCubit>.value(
            value: mockCubit,
            child: child,
          ),
        ),
      );
    }

    testWidgets('renders banner with founding badge and triggers open hub', (
      tester,
    ) async {
      when(() => mockCubit.state).thenReturn(
        const AutoCommunityState(
          status: AutoCommunityStatus.provisioned,
          community: tCommunity,
        ),
      );
      when(() => mockCubit.stream).thenAnswer(
        (_) => Stream.value(
          const AutoCommunityState(
            status: AutoCommunityStatus.provisioned,
            community: tCommunity,
          ),
        ),
      );

      StudyCommunityEntity? openedCommunity;
      String? joinedRoomId;

      await tester.pumpWidget(
        createTestApp(
          AutoCommunityBannerWidget(
            onTapOpenHub: (community) {
              openedCommunity = community;
            },
            onTapJoinRoom: (roomId) {
              joinedRoomId = roomId;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('WAEC-BIO'), findsOneWidget);
      expect(find.textContaining('56 peers'), findsOneWidget);
      expect(find.textContaining('Founding Member'), findsOneWidget);

      final openHubBtn = find.byKey(const Key('open_hub_button'));
      expect(openHubBtn, findsOneWidget);
      await tester.tap(openHubBtn);
      await tester.pump();

      expect(openedCommunity?.courseCode, equals('WAEC-BIO'));

      final joinRoomBtn = find.byKey(const Key('join_room_button'));
      expect(joinRoomBtn, findsOneWidget);
      await tester.tap(joinRoomBtn);
      await tester.pump();

      expect(joinedRoomId, equals('room_bio_pomodoro'));
    });

    testWidgets(
      'QuickJoinRoomChip displays active room and fires tap callback',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          createTestApp(
            QuickJoinRoomChip(
              roomId: 'room_123',
              roomTitle: 'Organic Chem 25m',
              activePeersCount: 8,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Organic Chem 25m'), findsOneWidget);
        expect(find.text('8'), findsOneWidget);

        await tester.tap(find.byType(QuickJoinRoomChip));
        await tester.pump();

        expect(tapped, isTrue);
      },
    );
  });
}
