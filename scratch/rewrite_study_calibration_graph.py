import re

with open('lib/src/features/planner/presentation/widgets/study_calibration_graph_widget.dart', 'r') as f:
    content = f.read()

# Add flutter_animate import
if 'import \'package:flutter_animate/flutter_animate.dart\';' not in content:
    content = content.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:flutter_animate/flutter_animate.dart';"
    )

content = content.replace(
    '''        ],
      ),
    );
  }

  Widget _buildMetricsBar(''',
    '''        ],
      ),
    ).animate()
      .fadeIn(duration: 400.ms, curve: Curves.easeOut)
      .slideY(begin: 0.05, end: 0, duration: 400.ms, curve: Curves.easeOutQuint);
  }

  Widget _buildMetricsBar('''
)

with open('lib/src/features/planner/presentation/widgets/study_calibration_graph_widget.dart', 'w') as f:
    f.write(content)
