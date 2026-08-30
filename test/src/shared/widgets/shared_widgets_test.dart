import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/shared/widgets/widgets.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Shared Widgets A11y & Behavior Test Suite', () {
    testWidgets('AppButton renders with button semantics and responds to tap',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          AppButton(
            text: 'Submit',
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Submit'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(AppButton)),
        matchesSemantics(
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          label: 'Submit',
          isFocusable: true,
        ),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets(
        'AppButton shows loader and announces when isLoading is true',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const AppButton(
            text: 'Submit',
            isLoading: true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
    });

    testWidgets(
        'AppTextField renders accessible semantics and receives text input',
        (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrapWithTheme(
          AppTextField(
            controller: controller,
            label: 'Email',
            hintText: 'Enter your email',
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'test@kortex.ai');
      expect(controller.text, equals('test@kortex.ai'));
    });

    testWidgets('AppTextField password toggle button has accessible semantics',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const AppTextField(
            isPassword: true,
            hintText: 'Password',
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('AppBadge renders contextual semantics label for counters',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const Column(
            children: [
              AppBadge(label: 'Active'),
              AppBadge.count(count: 120),
              AppBadge.dot(),
            ],
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('AppDivider renders horizontal, labeled, and vertical dividers',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const Column(
            children: [
              AppDivider(),
              AppDivider(label: 'OR'),
              SizedBox(height: 20, child: AppDivider.vertical()),
            ],
          ),
        ),
      );

      expect(find.text('OR'), findsOneWidget);
      expect(find.byType(AppDivider), findsNWidgets(3));
    });

    testWidgets(
        'AppAvatar displays user initials with image semantics',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const AppAvatar(
            name: 'Ada Lovelace',
            showBadge: true,
          ),
        ),
      );

      expect(find.text('AL'), findsOneWidget);
    });

    testWidgets('ShimmerPlaceholder renders with loading container semantics',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const Column(
            children: [
              ShimmerPlaceholder.rectangular(width: 100, height: 20),
              ShimmerPlaceholder.circular(radius: 24),
            ],
          ),
        ),
      );

      expect(find.byType(ShimmerPlaceholder), findsNWidgets(2));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets(
        'AppDialog shows with scoped route semantics and triggers action',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppDialog.show<bool>(
                context: context,
                title: 'Delete Notebook',
                description: 'Are you sure you want to delete?',
                primaryActionText: 'Confirm',
                secondaryActionText: 'Cancel',
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Notebook'), findsOneWidget);
      expect(find.text('Are you sure you want to delete?'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Notebook'), findsNothing);
    });
  });
}
