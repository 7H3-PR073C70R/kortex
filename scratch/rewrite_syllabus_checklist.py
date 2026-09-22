import re

with open('lib/src/features/planner/presentation/widgets/syllabus_checklist_widget.dart', 'r') as f:
    content = f.read()

# Add flutter_animate import
if 'import \'package:flutter_animate/flutter_animate.dart\';' not in content:
    content = content.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:flutter_animate/flutter_animate.dart';"
    )

content = content.replace(
    '''              _buildTopicItem(
                context,
                title: 'Data Flow & State Management',
                isCompleted: true,
              ),
              _buildTopicItem(
                context,
                title: 'Network Requests & APIs',
                isCompleted: false,
              ),
              _buildTopicItem(
                context,
                title: 'Local Storage & SQLite',
                isCompleted: false,
              ),''',
    '''              _buildTopicItem(
                context,
                title: 'Data Flow & State Management',
                isCompleted: true,
              ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1, curve: Curves.easeOutQuint),
              _buildTopicItem(
                context,
                title: 'Network Requests & APIs',
                isCompleted: false,
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1, curve: Curves.easeOutQuint),
              _buildTopicItem(
                context,
                title: 'Local Storage & SQLite',
                isCompleted: false,
              ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.1, curve: Curves.easeOutQuint),'''
)

with open('lib/src/features/planner/presentation/widgets/syllabus_checklist_widget.dart', 'w') as f:
    f.write(content)
