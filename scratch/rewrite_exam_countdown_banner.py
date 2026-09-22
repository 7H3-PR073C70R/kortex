import re

with open('lib/src/features/planner/presentation/widgets/exam_countdown_banner.dart', 'r') as f:
    content = f.read()

# Add flutter_animate import
if 'import \'package:flutter_animate/flutter_animate.dart\';' not in content:
    content = content.replace(
        "import 'package:flutter_bloc/flutter_bloc.dart';",
        "import 'package:flutter_bloc/flutter_bloc.dart';\nimport 'package:flutter_animate/flutter_animate.dart';"
    )

content = content.replace(
    '''            ),
          );
        }

        final days = exam.daysRemaining;''',
    '''            ).animate()
              .fadeIn(duration: 400.ms, curve: Curves.easeOut)
              .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuint),
          );
        }

        final days = exam.daysRemaining;'''
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
            .fadeIn(duration: 500.ms, curve: Curves.easeOut)
            .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeOutQuint),
        );
      },
    );
  }
}'''
)

with open('lib/src/features/planner/presentation/widgets/exam_countdown_banner.dart', 'w') as f:
    f.write(content)
