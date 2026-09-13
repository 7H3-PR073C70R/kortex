import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source.dart';
import 'package:kortex/src/features/community/presentation/widgets/report_content_modal_sheet.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockCommunityRemoteDataSource extends Mock
    implements CommunityRemoteDataSource {}

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late MockCommunityRemoteDataSource mockDataSource;

  setUp(() async {
    mockDataSource = MockCommunityRemoteDataSource();
    if (locator.isRegistered<CommunityRemoteDataSource>()) {
      await locator.unregister<CommunityRemoteDataSource>();
    }
    locator.registerSingleton<CommunityRemoteDataSource>(mockDataSource);
  });

  tearDown(() async {
    if (locator.isRegistered<CommunityRemoteDataSource>()) {
      await locator.unregister<CommunityRemoteDataSource>();
    }
  });

  group('ReportContentModalSheet Unit & Widget Tests', () {
    testWidgets('renders all report reason options and submit button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ReportContentModalSheet(
            contentType: 'forum_post',
            contentId: 'test_post_123',
            postId: 'test_post_123',
            contentTitle: 'Need help with kinematics',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Report Discussion'), findsOneWidget);
      expect(find.textContaining('Need help with kinematics'), findsOneWidget);
      expect(find.text('Academic Misinformation'), findsOneWidget);
      expect(find.text('Inappropriate or Offensive'), findsOneWidget);
      expect(find.text('Spam or Commercial Promotion'), findsOneWidget);
      expect(find.text('Harassment or Hostility'), findsOneWidget);
      expect(find.text('Other Concern'), findsOneWidget);
      expect(find.text('Submit Report'), findsOneWidget);
    });

    testWidgets('submitting report invokes CommunityRemoteDataSource.reportContent', (
      tester,
    ) async {
      when(
        () => mockDataSource.reportContent(
          contentType: any(named: 'contentType'),
          contentId: any(named: 'contentId'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          postId: any(named: 'postId'),
        ),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => ReportContentModalSheet.show(
                  context,
                  contentType: 'forum_post',
                  contentId: 'post_abc_456',
                  postId: 'post_abc_456',
                  contentTitle: 'Question about catapults',
                ),
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap on Spam
      await tester.tap(find.text('Spam or Commercial Promotion'));
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();

      verify(
        () => mockDataSource.reportContent(
          contentType: 'forum_post',
          contentId: 'post_abc_456',
          postId: 'post_abc_456',
          reason: 'Spam or Commercial Promotion',
        ),
      ).called(1);
    });

    testWidgets('context.showSnackBar displays top snackbar and is dismissible on swipe', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  context.showSnackBar(
                    message: 'Report submitted successfully!',
                    type: SnackBarType.success,
                  );
                },
                child: const Text('Show Notification'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Notification'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Report submitted successfully!'), findsOneWidget);
      expect(find.text('Success'), findsOneWidget);

      // Swipe up to dismiss
      await tester.drag(find.text('Report submitted successfully!'), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('Report submitted successfully!'), findsNothing);
    });
  });
}
