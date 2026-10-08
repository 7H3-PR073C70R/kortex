import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/navigation/app_tab_navigation.dart';

void main() {
  group('AppTabNavigation Dock and Main Index Mapping Tests', () {
    test(
      'dockIndexToMainIndex correctly maps 4 dock items to AutoTabsRouter main route indices',
      () {
        expect(
          AppTabNavigation.dockIndexToMainIndex(0),
          equals(0),
        ); // Home -> DashboardRoute
        expect(
          AppTabNavigation.dockIndexToMainIndex(1),
          equals(1),
        ); // Decks -> DecksRoute
        expect(
          AppTabNavigation.dockIndexToMainIndex(2),
          equals(3),
        ); // Hub -> StudyHubRoute
        expect(
          AppTabNavigation.dockIndexToMainIndex(3),
          equals(4),
        ); // Profile -> ProfileRoute
      },
    );

    test(
      'mainIndexToDockIndex correctly maps AutoTabsRouter main route indices to dock items',
      () {
        expect(
          AppTabNavigation.mainIndexToDockIndex(0),
          equals(0),
        ); // Home -> Dock 0
        expect(
          AppTabNavigation.mainIndexToDockIndex(1),
          equals(1),
        ); // Decks -> Dock 1
        expect(
          AppTabNavigation.mainIndexToDockIndex(2),
          equals(2),
        ); // Forum -> Dock 2
        expect(
          AppTabNavigation.mainIndexToDockIndex(3),
          equals(2),
        ); // Hub -> Dock 2
        expect(
          AppTabNavigation.mainIndexToDockIndex(4),
          equals(3),
        ); // Profile -> Dock 3
      },
    );

    test(
      'getMainTabIndex correctly resolves main route indices for AppMainTab enum',
      () {
        expect(AppTabNavigation.getMainTabIndex(AppMainTab.home), equals(0));
        expect(AppTabNavigation.getMainTabIndex(AppMainTab.decks), equals(1));
        expect(AppTabNavigation.getMainTabIndex(AppMainTab.forum), equals(2));
        expect(AppTabNavigation.getMainTabIndex(AppMainTab.hub), equals(3));
        expect(AppTabNavigation.getMainTabIndex(AppMainTab.profile), equals(4));
      },
    );
    test('hubSubTabs includes Forum only on compact (4-tab dock) layouts', () {
      expect(
        AppTabNavigation.hubSubTabs(isWide: false),
        equals([
          StudyHubSubTab.forum,
          StudyHubSubTab.liveRooms,
          StudyHubSubTab.studyCircles,
          StudyHubSubTab.marketplace,
        ]),
      );
      expect(
        AppTabNavigation.hubSubTabs(isWide: true),
        isNot(contains(StudyHubSubTab.forum)),
      );
    });

    test('hubTabControllerIndex resolves positions per layout', () {
      expect(
        AppTabNavigation.hubTabControllerIndex(
          StudyHubSubTab.forum,
          isWide: false,
        ),
        equals(0),
      );
      expect(
        AppTabNavigation.hubTabControllerIndex(
          StudyHubSubTab.marketplace,
          isWide: false,
        ),
        equals(3),
      );
      expect(
        AppTabNavigation.hubTabControllerIndex(
          StudyHubSubTab.marketplace,
          isWide: true,
        ),
        equals(2),
      );
      expect(
        AppTabNavigation.hubTabControllerIndex(
          StudyHubSubTab.forum,
          isWide: true,
        ),
        isNull,
      );
    });
  });
}
