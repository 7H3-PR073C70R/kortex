import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

/// Dropdown selector and custom domain field for Canvas LMS institutions.
class LmsCanvasInstitutionSelector extends StatelessWidget {
  const LmsCanvasInstitutionSelector({
    required this.selectedInstitution,
    required this.onInstitutionChanged,
    required this.customDomainController,
    required this.institutionPresets,
    super.key,
  });

  final String selectedInstitution;
  final ValueChanged<String> onInstitutionChanged;
  final TextEditingController customDomainController;
  final List<(String, String)> institutionPresets;

  bool get isCustomDomain => selectedInstitution == 'custom';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.lmsSelectInstitution,
          style: typography.caption.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceTertiary : colors.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: colors.surfaceBorder.withAlpha(100),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedInstitution,
              isExpanded: true,
              dropdownColor:
                  isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              items: institutionPresets.map((preset) {
                return DropdownMenuItem<String>(
                  value: preset.$1,
                  child: Text(
                    preset.$2,
                    style: typography.caption.medium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  onInstitutionChanged(val);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isCustomDomain) ...[
          AppTextField(
            controller: customDomainController,
            label: l10n.lmsCustomDomain,
            hintText: 'e.g. canvas.mycollege.edu',
            prefixIcon: const Icon(
              Icons.domain_rounded,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
