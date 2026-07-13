import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';

/// A user-supplied rating plus an optional comment. `score` ranges
/// 1.0-10.0 in 0.5 steps; the UI shows it as 10 stars (each star
/// half-toggles).
class UserRating {
  final String contentId;
  final String sourceId;
  final String? parentId;
  final double score;
  final String? comment;
  final DateTime ratedAt;
  /// Panel-independent TMDB id (if any). The read side uses this id to link
  /// a rating whose source was deleted to the same movie in the current
  /// catalog.
  final int? tmdbId;
  const UserRating({
    required this.contentId,
    required this.sourceId,
    required this.score,
    required this.ratedAt,
    this.parentId,
    this.comment,
    this.tmdbId,
  });
}

class UserRatingsNotifier
    extends AsyncNotifier<Map<String, UserRating>> {
  /// Map key: MediaItem.id ("sourceId|streamId"). We hold all ratings in
  /// memory for O(1) lookup; the total row count per user will not exceed
  /// the tens of thousands, so the cost is negligible.
  @override
  Future<Map<String, UserRating>> build() async {
    final db = ref.watch(databaseProvider);
    final rows = await db.select(db.userRatings).get();
    return {
      for (final r in rows)
        r.contentId: UserRating(
          contentId: r.contentId,
          sourceId: r.sourceId,
          parentId: r.parentId,
          score: r.score,
          comment: r.comment,
          ratedAt: r.ratedAt,
          tmdbId: r.tmdbId,
        ),
    };
  }

  Future<void> rate({
    required String sourceId,
    required String contentId,
    required double score,
    String? comment,
    String? parentId,
    int? tmdbId,
  }) async {
    final db = ref.read(databaseProvider);
    final clamped = score.clamp(1.0, 10.0);
    final now = DateTime.now();
    final cleanComment = (comment == null || comment.trim().isEmpty)
        ? null
        : comment.trim();
    await db
        .into(db.userRatings)
        .insertOnConflictUpdate(
          UserRatingsCompanion(
            contentId: Value(contentId),
            sourceId: Value(sourceId),
            parentId: Value(parentId),
            score: Value(clamped),
            comment: Value(cleanComment),
            ratedAt: Value(now),
            // Write tmdbId only if known; do not overwrite the old value with null.
            tmdbId: tmdbId == null ? const Value.absent() : Value(tmdbId),
          ),
        );
    // Optimistic state update - avoid the invalidateSelf rebuild flash.
    final current = state.value ?? const <String, UserRating>{};
    state = AsyncData({
      ...current,
      contentId: UserRating(
        contentId: contentId,
        sourceId: sourceId,
        parentId: parentId,
        score: clamped,
        comment: cleanComment,
        ratedAt: now,
        tmdbId: tmdbId ?? current[contentId]?.tmdbId,
      ),
    });
  }

  Future<void> remove({
    required String sourceId,
    required String contentId,
  }) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.userRatings)..where(
          (t) =>
              t.contentId.equals(contentId) & t.sourceId.equals(sourceId),
        ))
        .go();
    final current = state.value ?? const <String, UserRating>{};
    final updated = Map<String, UserRating>.from(current)..remove(contentId);
    state = AsyncData(updated);
  }

  UserRating? get(String contentId) => state.value?[contentId];
}

final userRatingsProvider =
    AsyncNotifierProvider<UserRatingsNotifier, Map<String, UserRating>>(
      UserRatingsNotifier.new,
    );
