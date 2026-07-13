/// Minimal, dependency-free fuzzy string matching.
///
/// Replaces the single `partialRatio` helper the app used from the
/// `fuzzywuzzy` package (which is GPL-2.0 licensed and would otherwise be the
/// only copyleft dependency in the tree). Only the behavior we actually rely
/// on is reproduced: a 0-100 partial-match score used with a high threshold
/// for typo-tolerant token search.
library;

/// Levenshtein edit distance between [a] and [b].
int _levenshtein(String a, String b) {
  final m = a.length;
  final n = b.length;
  if (m == 0) return n;
  if (n == 0) return m;
  var prev = List<int>.generate(n + 1, (i) => i);
  var curr = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final del = prev[j] + 1;
      final ins = curr[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      var best = del < ins ? del : ins;
      if (sub < best) best = sub;
      curr[j] = best;
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n];
}

/// Similarity of two equal-weight strings as a 0-100 score, derived from the
/// Levenshtein distance normalized by the longer length.
int _ratio(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 100;
  final maxLen = a.length > b.length ? a.length : b.length;
  if (maxLen == 0) return 100;
  final dist = _levenshtein(a, b);
  return ((1 - dist / maxLen) * 100).round();
}

/// Partial-match score (0-100) of the shorter string against the best-matching
/// window of the longer one. A short token that appears (exactly or with a
/// small typo) inside a longer word scores high, matching the `fuzzywuzzy`
/// `partialRatio` semantics the callers depend on.
int partialRatio(String s1, String s2) {
  if (s1.isEmpty || s2.isEmpty) return 0;
  final shorter = s1.length <= s2.length ? s1 : s2;
  final longer = s1.length <= s2.length ? s2 : s1;
  final windowLen = shorter.length;
  var best = 0;
  for (var i = 0; i + windowLen <= longer.length; i++) {
    final r = _ratio(shorter, longer.substring(i, i + windowLen));
    if (r > best) best = r;
    if (best == 100) break;
  }
  return best;
}
