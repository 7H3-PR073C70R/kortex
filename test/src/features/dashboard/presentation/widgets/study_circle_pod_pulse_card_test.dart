import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/pod_pulse/pod_metric_chip.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/pod_pulse/pod_pulse_card_item.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/study_circle_pod_pulse_card.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_circle_entity.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/pump_app.dart';

class MockCommunityHubBloc
    extends MockBloc<CommunityEvent, CommunityState>
    implements CommunityHubBloc {}

class MockUserActivityService extends Mock implements UserActivityService {}

void main() {
  group('StudyCirclePodPulseCard Widget Tests', () {
    late MockCommunityHubBloc mockCommunityHubBloc;
    late MockUserActivityService mockUserActivityService;

    const testCircles = [
      StudyCircleEntity(
        id: 'circle_1',
        name: 'Calculus Pioneers',
        track: 'Engineering',
        memberCount: 3,
        totalMinutesCompleted: 300,
        podQuest: 'Master Integrals',
      ),
      StudyCircleEntity(
        id: 'circle_2',
        name: 'Neural AI Pod',
        track: 'Computer Science',
        memberCount: 5,
        totalMinutesCompleted: 500,
        podQuest: 'Deep Learning Sprint',
      ),
    ];

    setUp(() {
      mockCommunityHubBloc = MockCommunityHubBloc();
      mockUserActivityService = MockUserActivityService();

      when(() => mockUserActivityService.getXpPoints()).thenReturn(450);
      when(() => mockUserActivityService.getWeeklyMinutesStudied())
          .thenReturn(120);

      when(() => mockCommunityHubBloc.state).thenReturn(
        const CommunityState(
          status: CommunityStatus.loaded,
          studyCircles: testCircles,
        ),
      );
    });

    testWidgets('renders Pod Pulse header, metric chips, and study pods',
        (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: SingleChildScrollView(
            child: StudyCirclePodPulseCard(
              targetTrack: 'Engineering',
              communityBloc: mockCommunityHubBloc,
              userActivityService: mockUserActivityService,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('LIVE SYNC'), findsOneWidget);
      expect(find.byType(PodMetricChip), findsNWidgets(3));
      expect(find.text('+450'), findsOneWidget);
      expect(find.text('AVAILABLE STUDY PODS'), findsOneWidget);
      expect(find.byType(PodPulseCardItem), findsWidgets);
      expect(find.text('Calculus Pioneers'), findsOneWidget);
    });

    testWidgets('shows empty state when no circles exist for track',
        (tester) async {
      when(() => mockCommunityHubBloc.state).thenReturn(
        const CommunityState(
          status: CommunityStatus.loaded,
        ),
      );

      await tester.pumpApp(
        Scaffold(
          body: SingleChildScrollView(
            child: StudyCirclePodPulseCard(
              targetTrack: 'Medicine',
              communityBloc: mockCommunityHubBloc,
              userActivityService: mockUserActivityService,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('No live pods for Medicine yet'), findsOneWidget);
      expect(find.text('Start a Pod Sprint'), findsOneWidget);
      expect(find.byType(PodPulseCardItem), findsNothing);
    });
  });
}
