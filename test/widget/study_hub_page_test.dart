import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/community/presentation/bloc/auto_community_cubit.dart';
import 'package:kortex/src/features/community/presentation/bloc/auto_community_state.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_state.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_circle_entity.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/study_rooms/presentation/pages/study_hub_page.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/study_circles_explainer_banner.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/study_hub_deck_marketplace_tab.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/study_hub_header_action_button.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/study_hub_live_rooms_tab.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/study_hub_study_circles_tab.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/pump_app.dart';

class MockCommunityHubBloc
    extends MockBloc<CommunityEvent, CommunityState>
    implements CommunityHubBloc {}

class MockAutoCommunityCubit
    extends MockCubit<AutoCommunityState>
    implements AutoCommunityCubit {}

class MockNotificationsCubit
    extends MockCubit<NotificationsState>
    implements NotificationsCubit {}

class MockDecksBloc extends MockBloc<DecksEvent, DecksState>
    implements DecksBloc {}

class MockDashboardBloc
    extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

void main() {
  group('StudyHubPage Widget Tests', () {
    late MockCommunityHubBloc mockCommunityBloc;
    late MockAutoCommunityCubit mockAutoCommunityCubit;
    late MockNotificationsCubit mockNotificationsCubit;
    late MockDecksBloc mockDecksBloc;
    late MockDashboardBloc mockDashboardBloc;

    const testRoom = StudyRoomEntity(
      id: 'room_1',
      title: 'Calculus Deep Dive',
      subject: 'Math',
      category: 'WAEC',
      activeParticipantsCount: 3,
      createdBy: 'user_1',
    );

    const testCircle = StudyCircleEntity(
      id: 'circle_1',
      name: 'STEM Scholars Pod',
      track: 'STEM',
      memberCount: 4,
      totalMinutesCompleted: 320,
    );

    const testDeck = SharedDeckEntity(
      id: 'deck_1',
      ownerId: 'user_2',
      ownerName: 'Dr. Mensah',
      title: 'Organic Chemistry Flashcards',
      subject: 'Chemistry',
      description: 'Comprehensive reactions',
      category: 'WAEC',
      syllabusTag: 'WAEC-CHEM',
      totalCards: 20,
    );

    setUp(() {
      mockCommunityBloc = MockCommunityHubBloc();
      mockAutoCommunityCubit = MockAutoCommunityCubit();
      mockNotificationsCubit = MockNotificationsCubit();
      mockDecksBloc = MockDecksBloc();
      mockDashboardBloc = MockDashboardBloc();

      when(() => mockAutoCommunityCubit.state).thenReturn(
        const AutoCommunityState(),
      );
      when(() => mockNotificationsCubit.state).thenReturn(
        const NotificationsState(),
      );
      when(() => mockDecksBloc.state).thenReturn(
        const DecksState(),
      );
      when(() => mockDashboardBloc.state).thenReturn(
        const DashboardState(),
      );

      when(() => mockCommunityBloc.state).thenReturn(
        const CommunityState(
          status: CommunityStatus.loaded,
          studyRooms: [testRoom],
          studyCircles: [testCircle],
          sharedDecks: [testDeck],
        ),
      );
    });

    tearDown(() async {
      await mockCommunityBloc.close();
      await mockAutoCommunityCubit.close();
      await mockNotificationsCubit.close();
      await mockDecksBloc.close();
      await mockDashboardBloc.close();
    });

    Widget buildSubject() {
      return StudyHubPage(
        communityHubBloc: mockCommunityBloc,
        autoCommunityCubit: mockAutoCommunityCubit,
        notificationsCubit: mockNotificationsCubit,
        decksBloc: mockDecksBloc,
        dashboardBloc: mockDashboardBloc,
      );
    }

    testWidgets('renders StudyHubPage with header action button and subtabs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpApp(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Hub'), findsOneWidget);
      expect(find.byType(StudyHubHeaderActionButton), findsOneWidget);
      expect(find.byType(StudyHubLiveRoomsTab), findsOneWidget);
      expect(find.text('Live Focus Rooms'), findsOneWidget);
      expect(find.text('Calculus Deep Dive'), findsOneWidget);
    });

    testWidgets(
      'switching to Study Pods tab displays StudyCirclesExplainerBanner',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpApp(buildSubject());
        await tester.pump();

        final podsTab = find.text('Study Pods');
        expect(podsTab, findsOneWidget);
        await tester.tap(podsTab);
        await tester.pumpAndSettle();

        expect(find.byType(StudyHubStudyCirclesTab), findsOneWidget);
        expect(find.byType(StudyCirclesExplainerBanner), findsOneWidget);
        expect(find.text('Peer Study Pods'), findsOneWidget);
      },
    );

    testWidgets(
      'switching to Marketplace tab displays decks and categories',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpApp(buildSubject());
        await tester.pump();

        final marketplaceTab = find.text('Deck Market');
        expect(marketplaceTab, findsOneWidget);
        await tester.tap(marketplaceTab);
        await tester.pumpAndSettle();

        expect(find.byType(StudyHubDeckMarketplaceTab), findsOneWidget);
        expect(find.text('Community Deck Marketplace'), findsOneWidget);
        expect(find.text('Organic Chemistry Flashcards'), findsOneWidget);
      },
    );
  });
}
