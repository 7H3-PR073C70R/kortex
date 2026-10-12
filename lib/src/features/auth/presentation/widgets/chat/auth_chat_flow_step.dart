import 'dart:math' as math;

/// Internal state machine steps for the conversational AI chat authentication flow.
enum ChatFlowStep {
  initial,
  signUpName,
  signUpEmail,
  signUpPassword,
  signUpPromoCode,
  loginEmail,
  loginPassword,
  forgotPasswordEmail,
  needsEmailConfirmation,
  accountActive,
  submitting,
}

/// Extension providing UI hints and input visibility metadata for [ChatFlowStep].
extension ChatFlowStepX on ChatFlowStep {
  bool get isTextFieldVisible =>
      this == ChatFlowStep.signUpName ||
      this == ChatFlowStep.signUpEmail ||
      this == ChatFlowStep.signUpPassword ||
      this == ChatFlowStep.loginEmail ||
      this == ChatFlowStep.loginPassword ||
      this == ChatFlowStep.forgotPasswordEmail ||
      this == ChatFlowStep.needsEmailConfirmation;

  bool get isPasswordField =>
      this == ChatFlowStep.signUpPassword ||
      this == ChatFlowStep.loginPassword;

  bool get isInputNeeded =>
      this == ChatFlowStep.initial ||
      this == ChatFlowStep.signUpPromoCode ||
      this == ChatFlowStep.needsEmailConfirmation ||
      this == ChatFlowStep.accountActive;

  String get hintText {
    switch (this) {
      case ChatFlowStep.signUpName:
        return 'Enter your full name...';
      case ChatFlowStep.signUpEmail:
      case ChatFlowStep.loginEmail:
      case ChatFlowStep.forgotPasswordEmail:
        return 'name@university.edu...';
      case ChatFlowStep.signUpPassword:
      case ChatFlowStep.loginPassword:
        return 'Enter password...';
      case ChatFlowStep.needsEmailConfirmation:
        return 'Enter 6-digit code...';
      case ChatFlowStep.initial:
      case ChatFlowStep.signUpPromoCode:
      case ChatFlowStep.accountActive:
      case ChatFlowStep.submitting:
        return 'Type a message...';
    }
  }
}

/// Curated motivational quotes displayed upon first greeting in the AI chat authentication flow.
const List<({String author, String quote})> authChatMotivationalQuotes = [
  (
    quote:
        'The beautiful thing about learning is that no one can '
        'take it away from you.',
    author: 'B.B. King',
  ),
  (
    quote:
        'Live as if you were to die tomorrow. '
        'Learn as if you were to live forever.',
    author: 'Mahatma Gandhi',
  ),
  (
    quote:
        'Education is the most powerful weapon which you can '
        'use to change the world.',
    author: 'Nelson Mandela',
  ),
  (
    quote: 'The mind is not a vessel to be filled, but a fire to be kindled.',
    author: 'Plutarch',
  ),
  (
    quote: 'An investment in knowledge pays the best interest.',
    author: 'Benjamin Franklin',
  ),
  (
    quote:
        'Develop a passion for learning. If you do, you will '
        'never cease to grow.',
    author: "Anthony J. D'Angelo",
  ),
  (
    quote:
        'The capacity to learn is a gift; the ability to learn is a skill; '
        'the willingness to learn is a choice.',
    author: 'Brian Herbert',
  ),
  (
    quote:
        'Wisdom is not a product of schooling but of the lifelong '
        'attempt to acquire it.',
    author: 'Albert Einstein',
  ),
  (
    quote:
        'Tell me and I forget. Teach me and I remember. '
        'Involve me and I learn.',
    author: 'Benjamin Franklin',
  ),
  (
    quote: 'There is no substitute for hard work and curious minds.',
    author: 'Thomas Edison',
  ),
];

/// Generates the initial Syllabot greeting message with a random motivational quote.
String generateAuthChatInitialGreeting() {
  final randomIndex = math.Random().nextInt(authChatMotivationalQuotes.length);
  final item = authChatMotivationalQuotes[randomIndex];
  return 'Hi Stranger! 👋 Welcome to Kortexify.\n\n'
      '✨ "${item.quote}" — ${item.author}\n\n'
      "I'm Syllabot, your AI study partner. "
      'How would you like to get started today?';
}
