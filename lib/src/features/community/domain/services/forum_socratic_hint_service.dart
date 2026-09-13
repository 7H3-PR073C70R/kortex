import 'dart:async';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';

/// Exception thrown when Syllabot is unable to generate an authentic AI response.
class SyllabotHintGenerationException implements Exception {
  const SyllabotHintGenerationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Intelligent Socratic Hint Generator for Forum Discussions and Community Q&A.
///
/// Ensures student questions receive high-yield, subject-specific Socratic guidance
/// directly from the neural engine (Cloud AI or On-Device Local LLM).
/// Never uses hardcoded or synthetic placeholder fallbacks.
class ForumSocraticHintService {
  const ForumSocraticHintService();

  /// Constructs a crisp, direct prompt for LLMs (Cloud and on-device)
  /// without confusing meta-instructions that cause small models to echo templates.
  static String buildPrompt(ForumPostEntity post) {
    final buffer = StringBuffer()
      ..writeln('You are Syllabot, an expert academic tutor with subject mastery across STEM and Humanities.')
      ..writeln('A student in "${post.track}" (${post.syllabusTag.isNotEmpty ? post.syllabusTag : post.track}) posted this discussion/problem:')
      ..writeln()
      ..writeln('Question Title: "${post.title}"');

    if (post.content.trim().isNotEmpty) {
      buffer.writeln('Details / Context:\n${post.content.trim()}');
    }
    if (post.latexContent != null && post.latexContent!.trim().isNotEmpty) {
      buffer.writeln('Formulas / LaTeX:\n${post.latexContent!.trim()}');
    }
    if (post.tags.isNotEmpty) {
      buffer.writeln('Tags: ${post.tags.join(', ')}');
    }

    buffer
      ..writeln()
      ..writeln(
        'Provide a concise, high-yield Socratic hint tailored specifically to the subject matter of this question.\n'
        'Do NOT copy the instructions below. Directly provide concrete academic concepts, formulas, or rules.\n\n'
        'Format your response using these 3 sections:\n'
        '💡 **Core Subject Principle**: State the specific law, theorem, formula, or fundamental academic concept governing this topic.\n'
        '🔍 **Concept Breakdown & Key Distinctions**: Explain how to analyze the problem, key variables or mechanisms to observe, and common traps or misconceptions to avoid.\n'
        '🎯 **Socratic Checkpoint**: One sharp, thought-provoking question that empowers the student to deduce the final answer themselves.',
      );

    return buffer.toString();
  }

  /// Identifies whether the generated response is a raw echo of prompt instructions
  /// or generic placeholder copy that lacks subject-matter depth.
  static bool isTemplateOrGenericEcho(String text) {
    if (text.trim().length < 25) return true;
    final lower = text.toLowerCase();

    // Verbatim phrases from prompt templates or common LLM echo patterns
    const forbiddenPhrases = [
      'explain the specific biological',
      'analyze key differences between the subject matter',
      'highlighting specific mechanisms or options mentioned by students',
      'a sharp guiding question that empowers the student into dedicating themselves',
      'dedicating themselves fully and making informed decisions',
      'state the specific law, theorem, formula, or fundamental',
      'explain how to analyze the problem, key variables',
      'one sharp, thought-provoking question that empowers',
      '[provide the specific',
      '[state the specific',
      '[explain how to',
      '[ask one sharp',
      'insert your explanation here',
      'your response here',
    ];

    for (final phrase in forbiddenPhrases) {
      if (lower.contains(phrase)) {
        return true;
      }
    }

    // Check for instruction header repetitions without substantive content
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.length <= 3) {
      final isAllHeaders = lines.every(
        (l) =>
            l.startsWith('Core Subject Principle:') ||
            l.startsWith('Concept Breakdown') ||
            l.startsWith('Socratic Checkpoint:'),
      );
      if (isAllHeaders && lower.contains('explain') && lower.contains('analyze')) {
        return true;
      }
    }

    return false;
  }

  /// Executes the full Socratic Hint pipeline with Cloud AI priority,
  /// automatic on-device fallback, and strict error reporting if generation fails.
  /// Throws [SyllabotHintGenerationException] if the AI engine is unavailable or returns empty.
  static Future<String> generateHint({
    required ForumPostEntity post,
    StreamSyllabotResponseUseCase? streamUseCase,
    LocalLlmEngineClient? localLlmClient,
    Future<void> Function(String hint)? onHintGenerated,
  }) async {
    // Step 0: Fast path - if post already has a cached Socratic hint, return immediately
    if (post.socraticHint != null &&
        post.socraticHint!.trim().isNotEmpty &&
        !isTemplateOrGenericEcho(post.socraticHint!)) {
      final cachedText = post.socraticHint!
          .replaceAll(RegExp(r'^🤖\s*Syllabot\s*Socratic\s*Hint:\s*', caseSensitive: false), '')
          .trim();
      return '🤖 Syllabot Socratic Hint:\n\n$cachedText';
    }

    final prompt = buildPrompt(post);
    var candidate = '';

    // Step 1: Cloud AI Streaming via Gemini / DeepSeek edge routing
    if (streamUseCase != null) {
      try {
        final stream = streamUseCase.call(
          prompt: prompt,
          sessionId: 'forum-hint-${post.id}',
          socraticMode: SocraticMode.stepByStep,
          preferredEngine: ExecutionEngineType.cloudRemote,
        );

        final buffer = StringBuffer();
        await stream
            .timeout(const Duration(seconds: 12), onTimeout: (s) => s.close())
            .forEach(buffer.write);

        final cloudCandidate = buffer.toString().trim();
        if (cloudCandidate.isNotEmpty && !isTemplateOrGenericEcho(cloudCandidate)) {
          candidate = cloudCandidate;
        }
      } on Object catch (_) {
        candidate = '';
      }
    }

    // Step 2: Fall back to on-device LLM stream if Cloud AI returned empty or failed
    if (candidate.isEmpty && streamUseCase != null) {
      try {
        final localStream = streamUseCase.call(
          prompt: prompt,
          sessionId: 'forum-hint-local-${post.id}',
          socraticMode: SocraticMode.stepByStep,
          preferredEngine: ExecutionEngineType.localOnDevice,
        );

        final buffer = StringBuffer();
        await localStream
            .timeout(const Duration(seconds: 8), onTimeout: (s) => s.close())
            .forEach(buffer.write);

        final localCandidate = buffer.toString().trim();
        if (localCandidate.isNotEmpty && !isTemplateOrGenericEcho(localCandidate)) {
          candidate = localCandidate;
        }
      } on Object catch (_) {}
    }

    // Step 3: Direct local LLM generation fallback if available
    if (candidate.isEmpty && localLlmClient != null) {
      try {
        if (localLlmClient.isModelDownloaded || localLlmClient.isInitialized) {
          final buffer = StringBuffer();
          await localLlmClient
              .generate(
                prompt: prompt,
                systemInstruction:
                    'Provide a direct, concrete academic Socratic hint for this question. Do not echo instructions.',
              )
              .timeout(const Duration(seconds: 8), onTimeout: (s) => s.close())
              .forEach(buffer.write);

          final directLocal = buffer.toString().trim();
          if (directLocal.isNotEmpty && !isTemplateOrGenericEcho(directLocal)) {
            candidate = directLocal;
          }
        }
      } on Object catch (_) {}
    }

    // Step 4: Strict Error Handling - Never return mock or heuristic fallback text
    if (candidate.isEmpty || isTemplateOrGenericEcho(candidate)) {
      throw const SyllabotHintGenerationException(
        'Unable to generate AI Socratic hint. Please check your internet connection or ensure on-device model is ready.',
      );
    }

    // Step 5: Clean up any markdown or prefix formatting
    final cleanText = candidate
        .replaceAll(RegExp(r'^🤖\s*Syllabot\s*Socratic\s*Hint:\s*', caseSensitive: false), '')
        .trim();

    final result = '🤖 Syllabot Socratic Hint:\n\n$cleanText';
    if (onHintGenerated != null) {
      unawaited(onHintGenerated(result));
    }

    return result;
  }
}
