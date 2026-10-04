import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';

/// Intelligent Fuzzy Duplicate Finder for Forum Threads & Questions.
///
/// Uses token-based Jaccard distance & track matching to identify similar
/// resolved discussions before users publish duplicate questions.
class ForumDuplicateDetector {
  const ForumDuplicateDetector._();

  /// Finds top similar discussion posts matching the given query title.
  static List<ForumPostEntity> findSimilarPosts({
    required String query,
    required List<ForumPostEntity> posts,
    String? track,
    double minSimilarity = 0.25,
  }) {
    final trimmed = query.trim();
    if (trimmed.length < 4) return const [];
    final queryTokens = _tokenize(trimmed);
    if (queryTokens.isEmpty) return const [];

    final matches = <MapEntry<ForumPostEntity, double>>[];
    for (final post in posts) {
      if (track != null &&
          track.trim().isNotEmpty &&
          track != 'All' &&
          track != 'General') {
        if (post.track.toLowerCase() != track.trim().toLowerCase()) {
          continue;
        }
      }
      final postTokens = _tokenize('${post.title} ${post.syllabusTag}');
      final similarity = _jaccardSimilarity(queryTokens, postTokens);
      if (similarity >= minSimilarity) {
        matches.add(MapEntry(post, similarity));
      }
    }

    matches.sort((a, b) => b.value.compareTo(a.value));
    return matches.map((e) => e.key).take(3).toList();
  }

  /// Checks if a post title has an exact or near-identical duplicate (> 80% match).
  static ForumPostEntity? findExactOrHighMatch({
    required String title,
    required List<ForumPostEntity> posts,
    String? track,
  }) {
    final matches = findSimilarPosts(
      query: title,
      posts: posts,
      track: track,
      minSimilarity: 0.75,
    );
    return matches.isNotEmpty ? matches.first : null;
  }

  static Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopwords.contains(w))
        .toSet();
  }

  static double _jaccardSimilarity(Set<String> setA, Set<String> setB) {
    if (setA.isEmpty || setB.isEmpty) return 0;
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union == 0 ? 0 : (intersection / union);
  }

  static const _stopwords = {
    'the',
    'and',
    'for',
    'that',
    'this',
    'with',
    'have',
    'from',
    'you',
    'what',
    'how',
    'why',
    'can',
    'does',
    'is',
    'are',
    'was',
    'were',
    'question',
    'problem',
    'discuss',
    'discussion',
  };
}
