import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_questions_filter_bar.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

/// Top search bar, exam year picker, and subject category filter bar.
class BoardSearchFilterHeader extends StatelessWidget {
  const BoardSearchFilterHeader({
    required this.searchController,
    required this.onSearchChanged,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 8),
    this.hintText = 'Search subjects and topics',
    super.key,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final EdgeInsetsGeometry padding;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: searchController,
                  hintText: hintText,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: colors.textSecondary,
                    size: 19,
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),
              const YearFilterButton(),
            ],
          ),
        ),
        const SubjectFilterBar(),
      ],
    );
  }
}
