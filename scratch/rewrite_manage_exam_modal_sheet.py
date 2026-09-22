import re

with open('lib/src/features/planner/presentation/widgets/manage_exam_modal_sheet.dart', 'r') as f:
    content = f.read()

# Add flutter_animate import
if 'import \'package:flutter_animate/flutter_animate.dart\';' not in content:
    content = content.replace(
        "import 'package:flutter_bloc/flutter_bloc.dart';",
        "import 'package:flutter_bloc/flutter_bloc.dart';\nimport 'package:flutter_animate/flutter_animate.dart';"
    )

content = content.replace(
    '''              children: [
                // Header''',
    '''              children: [
                // Header'''
)

content = content.replace(
    '''              ],
            ),
          ),
        );
      },
    );
  }
}''',
    '''              ],
            ),
          ).animate()
            .fadeIn(duration: 400.ms, curve: Curves.easeOut)
            .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuint),
        );
      },
    );
  }
}'''
)

with open('lib/src/features/planner/presentation/widgets/manage_exam_modal_sheet.dart', 'w') as f:
    f.write(content)
