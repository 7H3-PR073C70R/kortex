/// Represents a quick-start prompt suggestion shown in Syllabot empty state.
class PromptSuggestionModel {
  const PromptSuggestionModel({
    required this.text,
    required this.icon,
    required this.category,
  });

  final String text;
  final String icon;
  final String category;

  static List<PromptSuggestionModel> get defaults => const [
        PromptSuggestionModel(
          text: 'Derive the Euler-Lagrange equation from Hamilton\'s Principle',
          icon: '⚛️',
          category: 'Physics',
        ),
        PromptSuggestionModel(
          text: 'Explain Bayes\' theorem with a medical diagnosis example',
          icon: '📊',
          category: 'Statistics',
        ),
        PromptSuggestionModel(
          text: 'Solve the heat equation using separation of variables',
          icon: '🌡️',
          category: 'Mathematics',
        ),
        PromptSuggestionModel(
          text: 'Explain the CAP theorem in distributed systems',
          icon: '💻',
          category: 'Computer Science',
        ),
      ];
}
