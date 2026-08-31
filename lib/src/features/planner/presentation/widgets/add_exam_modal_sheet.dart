import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/l10n/l10n.dart';

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
    final theme = context.theme;
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Exam Name Field
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l10n.examNameLabel,
                  prefixIcon: const Icon(Icons.school_rounded),
                  filled: true,
                  fillColor: theme.colorScheme.surface.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                dropdownColor: theme.colorScheme.surface,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l10n.examSubjectLabel,
                  prefixIcon: const Icon(Icons.category_rounded),
                  filled: true,
                  fillColor: theme.colorScheme.surface.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'WAEC', child: Text('WAEC STEM')),
                  DropdownMenuItem(value: 'JAMB', child: Text('JAMB UTME')),
                  DropdownMenuItem(value: 'SAT', child: Text('SAT Digital')),
                  DropdownMenuItem(
                    value: 'University',
                    child: Text('University STEM'),
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
                    color: theme.colorScheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white24,
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
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.targetDateLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${_selectedDate.year}-'
                        '${_selectedDate.month.toString().padLeft(2, '0')}-'
                        '${_selectedDate.day.toString().padLeft(2, '0')}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  l10n.saveExamCountdown,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
