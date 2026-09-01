import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

class AddExamModalSheet extends StatefulWidget {
  const AddExamModalSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<CramPlannerCubit>(),
        child: const AddExamModalSheet(),
      ),
    );
  }

  @override
  State<AddExamModalSheet> createState() => _AddExamModalSheetState();
}

class _AddExamModalSheetState extends State<AddExamModalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedTrack = 'WAEC';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    unawaited(
      context.read<CramPlannerCubit>().addExamCountdown(
            examName: _nameController.text.trim(),
            targetDate: _selectedDate,
            subjectTrack: _selectedTrack,
            totalCardsCount: 150,
          ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 60 : 30),
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.addExamTitle,
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Exam Name Field
              AppTextField(
                controller: _nameController,
                label: l10n.examNameLabel,
                hintText: l10n.examModalExamTitleHint,
                prefixIcon: Icon(
                  Icons.school_rounded,
                  color: colors.textSecondary,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter exam name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Subject Track Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedTrack,
                dropdownColor:
                    isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                style: typography.body.regular.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: l10n.examSubjectLabel,
                  labelStyle: typography.subhead.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.category_rounded,
                    color: colors.textSecondary,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? colors.surfaceSecondary
                      : colors.surfacePrimary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colors.surfaceBorder,
                    ),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'WAEC',
                    child: Text(l10n.examTrackWaecStem),
                  ),
                  DropdownMenuItem(
                    value: 'JAMB',
                    child: Text(l10n.examTrackJambUtme),
                  ),
                  DropdownMenuItem(
                    value: 'SAT',
                    child: Text(l10n.examTrackSatDigital),
                  ),
                  DropdownMenuItem(
                    value: 'University',
                    child: Text(l10n.examTrackUniversityStem),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedTrack = val;
                    });
                  }
                },
              ),

              const SizedBox(height: 14),

              // Date Picker Tile
              InkWell(
                onTap: () {
                  unawaited(_pickDate());
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary
                        : colors.surfacePrimary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.surfaceBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 20,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.targetDateLabel,
                            style: typography.body.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${_selectedDate.year}-'
                        '${_selectedDate.month.toString().padLeft(2, '0')}-'
                        '${_selectedDate.day.toString().padLeft(2, '0')}',
                        style: typography.body.bold.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              AppButton(
                text: l10n.saveExamCountdown,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
