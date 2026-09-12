import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';

/// Centralized resolver for human-readable, descriptive study deck titles,
/// subject tags, and categories.
class DeckTitleResolver {
  const DeckTitleResolver._();

  static const Map<String, String> _knownSubjectNames = {
    'animalhusbandry': 'Animal Husbandry',
    'generalmathematics': 'General Mathematics',
    'mathematics': 'Mathematics',
    'maths': 'Mathematics',
    'english': 'Use of English',
    'useofenglish': 'Use of English',
    'biology': 'Biology',
    'chemistry': 'Chemistry',
    'physics': 'Physics',
    'economics': 'Economics',
    'government': 'Government',
    'literature': 'Literature in English',
    'literatureinenglish': 'Literature in English',
    'crk': 'Christian Religious Studies',
    'crs': 'Christian Religious Studies',
    'irk': 'Islamic Religious Studies',
    'irs': 'Islamic Religious Studies',
    'civiceducation': 'Civic Education',
    'geography': 'Geography',
    'accounting': 'Financial Accounting',
    'financialaccounting': 'Financial Accounting',
    'commerce': 'Commerce',
    'agriculturalscience': 'Agricultural Science',
    'agric': 'Agricultural Science',
    'furthermathematics': 'Further Mathematics',
    'computerscience': 'Computer Studies',
    'computerstudies': 'Computer Studies',
  };

  static bool isGenericTitle(String? title) {
    if (title == null || title.trim().isEmpty) return true;
    final clean = title.trim().toLowerCase();
    return clean == 'study deck' ||
        clean == 'canonical deck' ||
        clean == 'new study deck' ||
        clean == 'offline ai study deck' ||
        clean == 'general' ||
        clean == 'general studies' ||
        clean == 'deck';
  }

  static bool isGenericSubject(String? subject) {
    if (subject == null || subject.trim().isEmpty) return true;
    final clean = subject.trim().toLowerCase();
    return clean == 'general' ||
        clean == 'general studies' ||
        clean == 'general study' ||
        clean == 'uncategorized';
  }

  /// Parses canonical deck ID or raw string into clean components:
  /// (exam, subjectName, year)
  static ({String? exam, String? subject, int? year}) parseCanonicalDeckId(
    String deckId,
  ) {
    if (!deckId.startsWith('canonical_')) {
      return (exam: null, subject: null, year: null);
    }

    // Format: canonical_deck_{exam}_{subject}_{year} or canonical_{exam}_{subject}_{year}
    final raw = deckId.replaceFirst('canonical_deck_', '').replaceFirst('canonical_', '');
    final parts = raw.split('_');

    if (parts.isEmpty) {
      return (exam: null, subject: null, year: null);
    }

    final examRaw = parts[0].toUpperCase();
    final exam = (examRaw == 'UTME' || examRaw == 'JAMB')
        ? 'JAMB'
        : (examRaw == 'NECO' || examRaw == 'SSCE')
            ? 'NECO'
            : examRaw.isNotEmpty
                ? examRaw
                : 'WAEC';

    int? year;
    String subjectRaw;

    if (parts.length >= 3) {
      year = int.tryParse(parts.last);
      if (year != null) {
        subjectRaw = parts.sublist(1, parts.length - 1).join();
      } else {
        subjectRaw = parts.sublist(1).join();
      }
    } else if (parts.length == 2) {
      year = int.tryParse(parts[1]);
      if (year != null) {
        subjectRaw = '';
      } else {
        subjectRaw = parts[1];
      }
    } else {
      subjectRaw = '';
    }

    final cleanSubjectKey = subjectRaw.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    final resolvedSubject = _knownSubjectNames[cleanSubjectKey] ??
        _formatRawSubject(subjectRaw);

    return (
      exam: exam,
      subject: resolvedSubject.isNotEmpty ? resolvedSubject : null,
      year: year,
    );
  }

  static String _formatRawSubject(String raw) {
    if (raw.isEmpty) return '';
    // Insert spaces before capital letters if CamelCase
    final spaced = raw.replaceAllMapped(
      RegExp('([a-z])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    // Split by underscore, space, or hyphen and title case
    final tokens = spaced.split(RegExp(r'[_\s\-]+')).where((t) => t.isNotEmpty);
    return tokens
        .map((t) => t.length > 1
            ? '${t[0].toUpperCase()}${t.substring(1).toLowerCase()}'
            : t.toUpperCase())
        .join(' ');
  }

  /// Resolves the most descriptive title for a deck.
  static String resolveTitle({
    required String deckId,
    String? currentTitle,
    String? subject,
    String? courseCode,
    String? category,
  }) {
    if (!isGenericTitle(currentTitle)) {
      return currentTitle!.trim();
    }

    final canonical = parseCanonicalDeckId(deckId);
    if (canonical.exam != null) {
      final exam = canonical.exam!;
      final yearStr = canonical.year != null ? '${canonical.year} ' : '';
      final subj = canonical.subject ??
          (subject != null && !isGenericSubject(subject) ? subject : null) ??
          (courseCode != null && courseCode.isNotEmpty ? courseCode : 'Past Questions');

      return '$exam $yearStr$subj Past Questions'.replaceAll('  ', ' ').trim();
    }

    if (subject != null && !isGenericSubject(subject)) {
      return '$subject Active Recall Drill';
    }

    if (courseCode != null && courseCode.trim().isNotEmpty) {
      return '$courseCode Mastery Deck';
    }

    return 'Active Recall Study Deck';
  }

  /// Resolves the most descriptive subject label for a deck.
  static String resolveSubject({
    required String deckId,
    String? currentSubject,
    String? courseCode,
  }) {
    if (!isGenericSubject(currentSubject)) {
      return currentSubject!.trim();
    }

    final canonical = parseCanonicalDeckId(deckId);
    if (canonical.subject != null && canonical.subject!.isNotEmpty) {
      return canonical.subject!;
    }

    if (courseCode != null && courseCode.trim().isNotEmpty) {
      return courseCode.trim();
    }

    if (canonical.exam != null) {
      return canonical.exam!;
    }

    return 'General';
  }

  /// Resolves the most accurate category tag for a deck.
  static String resolveCategory({
    required String deckId,
    String? currentCategory,
  }) {
    if (currentCategory != null &&
        currentCategory.trim().isNotEmpty &&
        currentCategory.trim().toUpperCase() != 'GENERAL') {
      return currentCategory.trim();
    }

    final canonical = parseCanonicalDeckId(deckId);
    if (canonical.exam != null) {
      return canonical.exam!;
    }

    return 'Past Questions';
  }

  /// Decorates a [DeckModel] with descriptive titles and categories.
  static DeckModel enrichDeckModel(DeckModel deck) {
    final title = resolveTitle(
      deckId: deck.id,
      currentTitle: deck.title,
      subject: deck.subject,
      courseCode: deck.courseCode,
      category: deck.category,
    );
    final subject = resolveSubject(
      deckId: deck.id,
      currentSubject: deck.subject,
      courseCode: deck.courseCode,
    );
    final category = resolveCategory(
      deckId: deck.id,
      currentCategory: deck.category,
    );

    if (title == deck.title && subject == deck.subject && category == deck.category) {
      return deck;
    }

    return deck.copyWith(
      title: title,
      subject: subject,
      category: category,
    );
  }

  /// Decorates a [DeckEntity] with descriptive titles and categories.
  static DeckEntity enrichDeckEntity(DeckEntity deck) {
    final title = resolveTitle(
      deckId: deck.id,
      currentTitle: deck.title,
      subject: deck.subject,
      courseCode: deck.courseCode,
      category: deck.category,
    );
    final subject = resolveSubject(
      deckId: deck.id,
      currentSubject: deck.subject,
      courseCode: deck.courseCode,
    );
    final category = resolveCategory(
      deckId: deck.id,
      currentCategory: deck.category,
    );

    if (title == deck.title && subject == deck.subject && category == deck.category) {
      return deck;
    }

    return deck.copyWith(
      title: title,
      subject: subject,
      category: category,
    );
  }
}
