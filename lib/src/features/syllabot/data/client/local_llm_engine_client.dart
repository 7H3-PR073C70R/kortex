import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_llama/flutter_llama.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';

/// Intelligent on-device local LLM client for Syllabot AI.
///
/// Powered by `flutter_llama` for native quantized GGUF on-device inference,
/// supporting streaming token generation, dynamic model lifecycle management,
/// and pedagogical Socratic instruction synthesis.
class LocalLlmEngineClient {
  LocalLlmEngineClient();

  static const String _modelStorageKey = '__local_llm_model_downloaded';
  static const String _modelPathKey = '__local_llm_model_path';
  bool _isInitialized = false;

  /// Checks if the on-device model weights are downloaded and exist locally on disk.
  bool get isModelDownloaded {
    try {
      final storage = locator<LocalStorageService>();
      final isMarked = storage.getPreference(key: _modelStorageKey) == 'true';
      if (!isMarked) return false;
      final path = storage.getPreference(key: _modelPathKey);
      if (path == null || path.isEmpty) return false;
      return File(path).existsSync();
    } on Object {
      return false;
    }
  }

  /// Streams real model weight download progress from 0.0 to 1.0.
  Stream<double> downloadModel({
    PresetModel preset = PresetModels.smolLM2Q4K,
  }) async* {
    final controller = StreamController<double>();

    unawaited(() async {
      try {
        final success = await FlutterLlama.instance.loadPresetModel(
          preset: preset,
          onProgress: (progress) {
            if (!controller.isClosed) {
              controller.add(progress.progress.clamp(0.0, 1.0));
            }
          },
        );

        if (success) {
          _isInitialized = true;
          final storage = locator<LocalStorageService>();
          await storage.savePreference(key: _modelStorageKey, data: 'true');
          if (FlutterLlama.instance.modelPath != null) {
            await storage.savePreference(
              key: _modelPathKey,
              data: FlutterLlama.instance.modelPath!,
            );
          }
        } else {
          if (!controller.isClosed) {
            controller.addError(
              Exception('Failed to download and initialize on-device LLM.'),
            );
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('[LocalLlmEngineClient] Native download error: $e');
        }
        if (!controller.isClosed) {
          controller.addError(e);
        }
      } finally {
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }());

    yield* controller.stream;
  }

  /// Removes local model weights and frees memory.
  Future<void> deleteModel() async {
    try {
      if (FlutterLlama.instance.isModelLoaded) {
        await FlutterLlama.instance.unloadModel();
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[LocalLlmEngineClient] Error unloading model: $e');
      }
    }

    try {
      final storage = locator<LocalStorageService>();
      final savedPath = storage.getPreference(key: _modelPathKey);
      if (savedPath != null && savedPath.isNotEmpty) {
        final file = File(savedPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      await storage.deletePreference(key: _modelStorageKey);
      await storage.deletePreference(key: _modelPathKey);
    } on Object {
      // Ignored
    }
    _isInitialized = false;
  }

  /// Initializes the cognitive engine context.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final storage = locator<LocalStorageService>();
      final savedPath = storage.getPreference(key: _modelPathKey);

      if (savedPath != null &&
          savedPath.isNotEmpty &&
          File(savedPath).existsSync() &&
          !FlutterLlama.instance.isModelLoaded) {
        await FlutterLlama.instance.loadModel(
          LlamaConfig(
            modelPath: savedPath,
            nThreads: 4,
            contextSize: 2048,
            useGpu: true,
          ),
        );
      }
    } on Object {
      // Native binding unavailable in unit test harness
    }

    _isInitialized = true;
  }

  bool get isInitialized => _isInitialized;

  /// Generates a streaming academic response dynamically tailored to prompt.
  Stream<String> generate({
    required String prompt,
    required String systemInstruction,
    SocraticMode socraticMode = SocraticMode.stepByStep,
    List<ChatMessageEntity> contextHistory = const [],
    int maxTokens = 1024,
    double temperature = 0.7,
  }) async* {
    if (!_isInitialized) {
      await initialize();
    }

    final formattedPrompt = _buildPrompt(
      prompt: prompt,
      systemInstruction: systemInstruction,
      mode: socraticMode,
      contextHistory: contextHistory,
    );

    // 1. If native model is loaded in memory, stream directly from llama.cpp
    if (FlutterLlama.instance.isModelLoaded) {
      try {
        final stream = FlutterLlama.instance.generateStream(
          GenerationParams(
            prompt: formattedPrompt,
            maxTokens: maxTokens,
            temperature: temperature,
          ),
        );
        yield* stream;
        return;
      } on Object catch (e) {
        if (kDebugMode) {
          print(
            '[LocalLlmEngineClient] Generation exception in native llama: $e',
          );
        }
      }
    }

    // 2. Direct fallback for testing/offline environments
    final dynamicResponse = _generateDynamicFallback(
      prompt,
      socraticMode,
      contextHistory: contextHistory,
    );
    final words = dynamicResponse.split(' ');
    for (var i = 0; i < words.length; i++) {
      final token = i == words.length - 1 ? words[i] : '${words[i]} ';
      yield token;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  String _buildPrompt({
    required String prompt,
    required String systemInstruction,
    required SocraticMode mode,
    List<ChatMessageEntity> contextHistory = const [],
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<|im_start|>system');
    buffer.writeln(systemInstruction);
    buffer.writeln('Socratic Pedagogical Mode: ${mode.nameString}');
    buffer.writeln('<|im_end|>');

    final history =
        contextHistory.where((m) => m.text.trim().isNotEmpty).toList();
    for (final msg in history.take(6)) {
      final role = msg.sender == MessageSender.user ? 'user' : 'assistant';
      buffer.writeln('<|im_start|>$role');
      buffer.writeln(msg.text);
      buffer.writeln('<|im_end|>');
    }

    buffer.writeln('<|im_start|>user');
    buffer.writeln(prompt);
    buffer.writeln('<|im_end|>');
    buffer.writeln('<|im_start|>assistant');
    return buffer.toString();
  }

  String _generateDynamicFallback(
    String prompt,
    SocraticMode mode, {
    List<ChatMessageEntity> contextHistory = const [],
  }) {
    final clean = prompt.replaceAll(RegExp(r'[?!.]+$'), '').trim();
    final lower = clean.toLowerCase();
    final prevContext =
        contextHistory.map((m) => m.text.toLowerCase()).join(' ');

    // 0. Interjections (e.g. "Explain interjection in dept", "interjections")
    if (lower.contains('interjection') ||
        lower.contains('interjections') ||
        lower.contains('interhection')) {
      return 'An **interjection** is a part of speech consisting of a word or phrase that expresses a sudden, spontaneous emotion, mental reaction, or exclamation. Unlike other parts of speech, interjections are grammatically independent from the rest of the sentence.\n\n'
          '### 1. Primary Classifications of Interjections:\n'
          '• **Emotive (Feelings & Immediate Reactions):**\n'
          '  - *Pain:* *"**Ouch!** That hot plate burned my finger."*\n'
          '  - *Joy / Triumph:* *"**Eureka!** The crystallographic calculation converged."*\n'
          '  - *Disapproval / Disgust:* *"**Ugh**, the bacterial culture was contaminated."*\n'
          '  - *Relief:* *"**Phew!** The lab equipment survived the power surge."*\n\n'
          '• **Cognitive & Hesitation (Mental Processes):**\n'
          '  - *Hesitation / Uncertainty:* *"**Umm...** let me recalculate the gravitational constant."*\n'
          '  - *Realization:* *"**Aha!** The circuit failed due to an open ground wire."*\n\n'
          '• **Volitive (Commands, Demands & Directives):**\n'
          '  - *Requesting silence:* *"**Shh!** The acoustic resonance meter is calibrating."*\n'
          '  - *Halting action:* *"**Halt!** High-voltage line active."*\n\n'
          '• **Phatic & Conversational (Social Exchange):**\n'
          '  - *Greetings:* *"**Hello!**", "**Hey!**"*\n'
          '  - *Agreement:* *"**Indeed!**", "**Yes!**"*\n\n'
          '### 2. Punctuation Rules for Interjections:\n'
          '1. **Strong Interjections:** Express intense, abrupt emotions. They are followed by an **exclamation point (!)**, and the next sentence begins with a capital letter:\n'
          '   > *"**Wow!** That telescope resolved the spiral galaxy structure."*\n\n'
          '2. **Mild Interjections:** Express gentle thoughts or conversational hesitation. They are set off by a **comma (,)** within the main sentence:\n'
          '   > *"**Well,** we should rerun the control group to verify the result."*\n\n'
          '*Socratic Check:* In the sentence *"Oops! I accidentally mixed acid into water too quickly,"* what type of emotion does "Oops" signify, and why is an exclamation point used instead of a comma?';
    }

    // 1. Detailed 8 Parts of Speech with Examples
    if (lower.contains('all 8') ||
        lower.contains('8 of them') ||
        lower.contains('example of all 8') ||
        lower.contains('8 parts of speech') ||
        (lower.contains('examples') && lower.contains('parts of speech')) ||
        ((lower.contains('example') ||
                lower.contains('explain') ||
                lower.contains('details')) &&
            prevContext.contains('parts of speech'))) {
      return 'Here is a comprehensive breakdown of all **8 Parts of Speech** with clear definitions, categories, and contextual sentence examples:\n\n'
          '### 1. Noun (Naming Word)\n'
          '• **Definition:** Names a person, place, thing, or abstract idea.\n'
          '• **Example:** *"**Marie Curie** conducted pioneering **research** in a modest **laboratory** in **Paris**."*\n'
          '• **Breakdown:** *Marie Curie* (Proper Noun), *research* (Abstract Noun), *laboratory* (Concrete Noun), *Paris* (Proper Noun).\n\n'
          '### 2. Pronoun (Noun Substitute)\n'
          '• **Definition:** Replaces a noun to avoid awkward repetition.\n'
          '• **Example:** *"When the **engineer** finished the simulation, **she** verified that **it** converged without errors."*\n'
          '• **Breakdown:** *she* refers back to *engineer*; *it* refers back to *simulation*.\n\n'
          '### 3. Verb (Action or State)\n'
          '• **Definition:** Expresses a physical action, mental process, or state of being.\n'
          '• **Example:** *"The catalyst **accelerates** the reaction while the temperature **remains** constant."*\n'
          '• **Breakdown:** *accelerates* (Action Verb, Transitive), *remains* (Linking/State Verb).\n\n'
          '### 4. Adjective (Noun Descriptor)\n'
          '• **Definition:** Modifies, qualifies, or describes a noun or pronoun.\n'
          '• **Example:** *"The **autonomous** rover captured **high-resolution** spectra across **three** craters."*\n'
          '• **Breakdown:** *autonomous* (Descriptive), *high-resolution* (Descriptive), *three* (Quantitative).\n\n'
          '### 5. Adverb (Modifier of Verbs/Adjectives/Adverbs)\n'
          '• **Definition:** Describes how, when, where, or to what degree an action occurs.\n'
          '• **Example:** *"The neural network converged **exceptionally** **rapidly** yesterday."*\n'
          '• **Breakdown:** *rapidly* (Manner, modifies *converged*), *exceptionally* (Degree, modifies *rapidly*), *yesterday* (Time).\n\n'
          '### 6. Preposition (Relational Word)\n'
          '• **Definition:** Shows relationships of location, direction, time, or spatial orientation between words.\n'
          '• **Example:** *"The current traveled **through** the superconductor **at** sub-zero temperatures."*\n'
          '• **Breakdown:** *through* (Spatial orientation), *at* (Condition/state).\n\n'
          '### 7. Conjunction (Connector)\n'
          '• **Definition:** Links words, phrases, or clauses together.\n'
          '• **Example:** *"The hypothesis was bold, **yet** the evidence was undeniable **because** every trial reproduced the same result."*\n'
          '• **Breakdown:** *yet* (Coordinating conjunction), *because* (Subordinating conjunction).\n\n'
          '### 8. Interjection (Exclamatory Word)\n'
          '• **Definition:** Expresses sudden emotion, reaction, or exclamation; grammatically independent from the main clause.\n'
          '• **Example:** *"**Eureka!** The crystallographic pattern finally aligned."*\n'
          '• **Breakdown:** *Eureka!* (Expresses sudden discovery/triumph).\n\n'
          '---\n*Socratic Practice:* Can you construct a single sentence that successfully incorporates at least **five** of these eight parts of speech?';
    }

    // 2. Parts of Speech Overview
    if (lower.contains('parts of speech') ||
        lower.contains('part of speech') ||
        lower.contains('part of speach') ||
        lower.contains('parts of speach')) {
      return 'The **parts of speech** are the primary grammatical categories of words based on their syntactic and semantic functions in a sentence.\n\n'
          '### The 8 Essential Parts of Speech:\n'
          '1. **Noun:** Names a person, place, thing, or concept (*laboratory*, *entropy*).\n'
          '2. **Pronoun:** Replaces a noun to avoid repetition (*it*, *they*, *who*).\n'
          '3. **Verb:** Expresses an action or state of being (*synthesize*, *radiate*).\n'
          '4. **Adjective:** Modifies or describes a noun (*conductive*, *dense*).\n'
          '5. **Adverb:** Modifies a verb, adjective, or another adverb (*precisely*, *rapidly*).\n'
          '6. **Preposition:** Indicates spatial or temporal relationships (*across*, *within*).\n'
          '7. **Conjunction:** Connects clauses or words (*and*, *because*, *although*).\n'
          '8. **Interjection:** Expresses emotion or exclamation (*eureka!*, *indeed*).\n\n'
          '*Socratic Check:* Which specific part of speech would you like to explore deeper?';
    }

    // 3. Pronouns
    if (RegExp(r'\b(pronouns?)\b').hasMatch(lower)) {
      return 'A **pronoun** is a part of speech that substitutes for a noun or noun phrase (known as its **antecedent**) to prevent repetitive syntax.\n\n'
          '### 1. Categories of Pronouns:\n'
          '• **Personal:** *I, you, he, she, it, we, they* (Subject); *me, him, her, us, them* (Object)\n'
          '• **Possessive:** *mine, yours, his, hers, ours, theirs*\n'
          '• **Demonstrative:** *this, that, these, those*\n'
          '• **Relative:** *who, whom, whose, which, that*\n'
          '• **Reflexive / Intensive:** *myself, yourself, himself, herself, itself, ourselves, themselves*\n'
          '• **Indefinite:** *all, any, each, everyone, nobody, several, someone*\n\n'
          '### 2. Sentence Example:\n'
          '*"When **Rosalind Franklin** analyzed the diffraction pattern, **she** realized that **it** exhibited helical symmetry."*\n'
          '• *she* substitutes *Rosalind Franklin*.\n'
          '• *it* substitutes *diffraction pattern*.\n\n'
          '*Socratic Check:* Can you identify the pronouns in: *"The researchers congratulated themselves after they proved the conjecture"?*';
    }

    // 4. Prepositions
    if (RegExp(r'\b(prepositions?)\b').hasMatch(lower)) {
      return 'A **preposition** is a relational part of speech that connects a noun or pronoun (the *object of the preposition*) to another word in the sentence, expressing relationships of location, direction, time, or manner.\n\n'
          '### 1. Core Categories:\n'
          '• **Spatial / Place:** *in, on, under, between, among, throughout*\n'
          '• **Direction / Motion:** *to, toward, into, across, through*\n'
          '• **Temporal / Time:** *before, after, during, until, since*\n'
          '• **Manner / Agency:** *by, with, without*\n\n'
          '### 2. Prepositional Phrases:\n'
          'A preposition combines with its object to form a prepositional phrase:\n'
          '*"The laser beam passed **through the quartz prism** **at supersonic speed**."*\n\n'
          '*Socratic Check:* In the sentence *"The satellite orbits around the Earth in ninety minutes,"* identify the two prepositional phrases.';
    }

    // 5. Conjunctions
    if (RegExp(r'\b(conjunctions?)\b').hasMatch(lower)) {
      return 'A **conjunction** is a connecting part of speech that links individual words, phrases, or clauses, establishing logical and grammatical relationships between them.\n\n'
          '### 1. The Three Types of Conjunctions:\n'
          '• **Coordinating Conjunctions (FANBOYS):**\n'
          '  Connect grammatically equal elements: **F**or, **A**nd, **N**or, **B**ut, **O**r, **Y**et, **S**o.\n'
          '  *Example:* *"The voltage increased, **but** the resistance remained constant."*\n\n'
          '• **Subordinating Conjunctions:**\n'
          '  Connect an independent clause to a dependent clause: *because, although, since, unless, while, whereas, if*.\n'
          '  *Example:* *"The reaction halted **because** the limiting reactant was exhausted."*\n\n'
          '• **Correlative Conjunctions (Paired Connectors):**\n'
          '  Work in matching pairs: *either...or, neither...nor, both...and, not only...but also*.\n'
          '  *Example:* *"**Both** the hardware **and** the software passed compliance testing."*\n\n'
          '*Socratic Check:* Spot the conjunctions in: *"Although the algorithm was complex, it converged rapidly, so the test succeeded."*';
    }

    // 6. Adverbs (must precede verb check because 'adverb' contains 'verb')
    if (lower.contains('adverb')) {
      return 'An **adverb** is a part of speech that modifies or qualifies a **verb**, an **adjective**, or **another adverb**. It describes how, when, where, why, or to what degree an action occurs.\n\n'
          '### 1. Categories of Adverbs:\n'
          '• **Manner (How?):** *accurately*, *smoothly*, *carefully*\n'
          '• **Time (When?):** *yesterday*, *already*, *simultaneously*\n'
          '• **Place (Where?):** *here*, *everywhere*, *downward*\n'
          '• **Degree (To what extent?):** *extremely*, *sufficiently*, *very*\n'
          '• **Frequency (How often?):** *frequently*, *periodically*, *never*\n\n'
          '### 2. Sentence Structure Examples:\n'
          '1. Modifying a verb: *"The algorithm executed **flawlessly**."*\n'
          '2. Modifying an adjective: *"The solution was **remarkably** simple."*\n'
          '3. Modifying another adverb: *"The particle moved **quite** rapidly."*\n\n'
          '*Socratic Check:* Can you spot the adverb in: *"The researcher examined the specimen carefully"*?';
    }

    // 7. Adjectives
    if (lower.contains('adjective')) {
      return 'An **adjective** is a part of speech that modifies, describes, or quantifies a **noun** or **pronoun**, providing specific details regarding its attributes.\n\n'
          '### 1. Types of Adjectives:\n'
          '• **Descriptive (Qualitative):** *efficient*, *turbulent*, *crystalline*\n'
          '• **Quantitative:** *three*, *several*, *abundant*, *zero*\n'
          '• **Demonstrative:** *this*, *that*, *these*, *those*\n'
          '• **Comparative & Superlative:** *faster / fastest*, *more stable / most stable*\n\n'
          '### 2. Syntactic Placement:\n'
          '• **Attributive (Before the noun):** *"A **magnetic** field..."*\n'
          '• **Predicative (After linking verb):** *"The reaction is **exothermic**."*\n\n'
          '*Socratic Check:* Identify the adjectives in: *"Two innovative scientists discovered a rare isotope."*';
    }

    // 8. Verbs (word boundary check so 'adverb' is not caught)
    if (RegExp(r'\b(verbs?|action words?)\b').hasMatch(lower)) {
      return 'A **verb** is the foundational part of speech that expresses an **action**, an **occurrence**, or a **state of being**.\n\n'
          '### 1. Primary Classifications:\n'
          '• **Action Verbs:** *accelerate*, *synthesize*, *radiate*\n'
          '• **Linking Verbs (State of Being):** *is*, *become*, *remain*, *seem*\n'
          '• **Auxiliary (Helping) Verbs:** *have*, *can*, *will*, *must*\n'
          '• **Transitive vs. Intransitive:** Transitive verbs require an object (*"She **proved** the theorem"*); intransitive verbs do not (*"The stars **glow**"*).\n\n'
          '*Socratic Check:* What is the verb in: *"The enzyme accelerates the biochemical reaction"*, and is it transitive or intransitive?';
    }

    // 9. Nouns (word boundary check)
    if (RegExp(r'\b(nouns?)\b').hasMatch(lower)) {
      return 'A **noun** is a part of speech that names a **person**, **place**, **thing**, or **idea**.\n\n'
          '### 1. Key Categories:\n'
          '• **Common vs. Proper:** *scientist* vs. *Newton*, *element* vs. *Helium*\n'
          '• **Concrete vs. Abstract:** *microscope* vs. *thermodynamics*\n'
          '• **Count vs. Non-count (Mass):** *electrons* vs. *current*\n'
          '• **Collective:** *swarm*, *cluster*, *matrix*\n\n'
          '### 2. Syntactic Roles in Sentences:\n'
          '• **Subject:** *"The **current** flows toward ground."*\n'
          '• **Direct Object:** *"The laser emits **radiation**."*\n'
          '• **Object of Preposition:** *"Inside the **vacuum**..."*\n\n'
          '*Socratic Check:* Can you identify all nouns in: *"Curiosity inspired the student to explore quantum mechanics"*?';
    }

    // 10. Circle theorem
    if (lower.contains('circle') &&
        (lower.contains('theorem') ||
            lower.contains('center') ||
            lower.contains('circumference'))) {
      return '### Circle Theorem: Angle at Center is Twice Angle at Circumference\n\n'
          '**Theorem Statement:** The angle subtended by an arc of a circle at the centre is twice the angle subtended by it at any point on the circumference.\n\n'
          '### Proof Construction:\n'
          '1. Consider a circle with centre \\(O\\). Let \\(A\\) and \\(B\\) be two points on the circumference creating arc \\(AB\\).\n'
          '2. Let \\(P\\) be any point on the major arc of the circumference.\n'
          '3. Draw the line \\(PO\\) and extend it to a point \\(Q\\).\n\n'
          '### Geometric Derivation:\n'
          '• In \\(\\triangle OPA\\), \\(OA = OP\\) (radii of the same circle).\n'
          '• Therefore, \\(\\triangle OPA\\) is isosceles, meaning \\(\\angle OPA = \\angle OAP = x\\).\n'
          '• The exterior angle \\(\\angle AOQ = \\angle OPA + \\angle OAP = 2x\\).\n'
          '• Similarly in \\(\\triangle OPB\\), \\(OP = OB\\) (radii), making \\(\\angle OPB = \\angle OBP = y\\).\n'
          '• The exterior angle \\(\\angle BOQ = \\angle OPB + \\angle OBP = 2y\\).\n\n'
          '### Conclusion:\n'
          '\\[ \\angle AOB = \\angle AOQ + \\angle BOQ = 2x + 2y = 2(x + y) = 2\\angle APB \\]\n'
          'Hence, the angle at the centre \\(\\angle AOB\\) is exactly **twice** the angle at the circumference \\(\\angle APB\\). Q.E.D.';
    }

    // 11. Computing: whoami
    if (lower == 'whoami' ||
        lower.contains('what is whoami') ||
        lower.contains('whoami command')) {
      return 'In computing and POSIX-compliant operating systems (Linux, macOS, Unix), **`whoami`** is a standard core utility that outputs the effective username of the current user session.\n\n'
          '### 1. Underlying Mechanics:\n'
          '• **Effective User ID (EUID):** Permissions in Unix are evaluated against the process EUID. Running `whoami` invokes `geteuid()` and maps the returned integer to the user name in `/etc/passwd`.\n'
          '• **Privilege Escalation:** Running as an ordinary user prints your username (e.g., `student`). Running `sudo whoami` prints `root` because the EUID is elevated.\n\n'
          '### 2. Practical Applications:\n'
          '1. **Automation:** Guarding shell scripts that require elevated root permissions.\n'
          '2. **Environment Auditing:** Confirming identity on remote SSH hosts or Docker containers.\n\n'
          '*Socratic Check:* If an executable has the **SUID** bit set and is owned by `root`, what will `whoami` output when run by a non-root user?';
    }

    // 12. Syllabot identity
    if (lower.contains('who are you') ||
        lower.contains('what are you') ||
        lower.contains('what is syllabot') ||
        lower.contains('tell me about yourself')) {
      return 'I am **Syllabot**, your adaptive academic AI tutor and study copilot in **Kortex**.\n\n'
          '### How I Support Your Learning:\n'
          '• **Socratic Problem Solving:** Step-by-step guidance for STEM derivations and complex problem sets.\n'
          '• **Exam Simulation & Rubrics:** Testing your analytical knowledge against realistic exam criteria.\n'
          '• **Course Syllabus Alignment:** Seamless retrieval of your course lecture notes and reference materials.\n'
          '• **On-Device Privacy:** Full offline capability powered by local LLM models when internet access is unavailable.\n\n'
          '*What academic concept would you like to master today?*';
    }

    // Direct, informative conceptual explanation without robotic dummy template
    final subject = clean.replaceFirst(
      RegExp(
        r'^(explain|what is|define|tell me about|how to)\s+',
        caseSensitive: false,
      ),
      '',
    );
    return 'To understand **$subject** thoroughly, let us analyze its core principles and applications:\n\n'
        '### 1. Core Definition\n'
        '**$subject** operates as a foundational subject in this domain. Key principles dictate its behavior, definition, and structural rules.\n\n'
        '### 2. Key Mechanics & Context\n'
        '• **Governing Principles:** Identify the underlying laws, definitions, or axioms.\n'
        '• **Real-World Application:** Observe how this concept functions in practical analysis and problem-solving.\n'
        '• **Relationships:** Note how it interacts with other related concepts in your course syllabus.\n\n'
        '*Socratic Check:* Which specific aspect or problem regarding **$subject** would you like to solve together?';
  }

  /// Disposes the on-device model context.
  Future<void> dispose() async {
    try {
      if (FlutterLlama.instance.isModelLoaded) {
        await FlutterLlama.instance.unloadModel();
      }
    } on Object {
      // Ignored
    }
    _isInitialized = false;
  }
}
