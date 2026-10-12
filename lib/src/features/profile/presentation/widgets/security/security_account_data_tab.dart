import 'package:flutter/material.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_account_credentials_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_data_portability_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_storage_cache_section.dart';

/// The 'Account & Data' tab content in SecuritySettingsPage.
class SecurityAccountDataTab extends StatelessWidget {
  const SecurityAccountDataTab({
    required this.displayName,
    required this.email,
    required this.onSaveDisplayName,
    required this.onExportDecks,
    required this.onExportGdprBundle,
    super.key,
  });

  final String displayName;
  final String email;
  final Future<void> Function(String newName) onSaveDisplayName;
  final VoidCallback onExportDecks;
  final VoidCallback onExportGdprBundle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('account_data_tab'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Account Credentials
          SecurityAccountCredentialsSection(
            displayName: displayName,
            email: email,
            onSaveDisplayName: onSaveDisplayName,
          ),
          const SizedBox(height: 20),

          // 2. Data Portability & Export (Anki, PDF, CSV)
          SecurityDataPortabilitySection(
            onExportDecks: onExportDecks,
            onExportGdprBundle: onExportGdprBundle,
          ),
          const SizedBox(height: 20),

          // 3. Storage & AI Cache Management
          const SecurityStorageCacheSection(),
        ],
      ),
    );
  }
}
