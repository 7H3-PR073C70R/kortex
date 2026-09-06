import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/features/profile/presentation/pages/security_settings_page.dart';

/// Consolidated into [SecuritySettingsPage] with tabbed controls.
///
/// Retained as a route wrapper defaulting to the "Account & Data" tab
/// for backward compatibility across navigation paths.
@RoutePage()
class AccountSecurityPage extends StatelessWidget {
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SecuritySettingsPage(initialTabIndex: 1);
  }
}
