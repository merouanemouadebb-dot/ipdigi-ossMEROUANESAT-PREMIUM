import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/database_provider.dart';

/// TMDB matches the user has manually corrected. We load every row
/// into memory and expose them as Map<contentId, override>; the match
/// lookup runs on every detail page so it needs to be O(1).
class TmdbOverride {
  final String contentId;
  final String sourceId;
  final int tmdbId;
  final bool isMovie;
  final DateTime savedAt;
  const TmdbOverride({
    required this.contentId,
    required this.sourceId,
    required this.tmdbId,
    required this.isMovie,
    required this.savedAt,
  });
}

class TmdbOverridesNotifier
    extends AsyncNotifier<Map<String, TmdbOverride>> {
  @override
  Future<Map<String, TmdbOverride>> build() async {
    final db = ref.watch(databaseProvider);
    final rows = await db.select(db.tmdbOverrides).get();
    return {
      for (final r in rows)
        r.contentId: TmdbOverride(
          contentId: r.contentId,
          sourceId: r.sourceId,
          tmdbId: r.tmdbId,
          isMovie: r.isMovie,
          savedAt: r.savedAt,
        ),
    };
  }

  Future<void> save({
    required String contentId,
    required String sourceId,
    required int tmdbId,
    required bool isMovie,
  }) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    await db.into(db.tmdbOverrides).insertOnConflictUpdate(
          TmdbOverridesCompanion(
            contentId: Value(contentId),
            sourceId: Value(sourceId),
            tmdbId: Value(tmdbId),
            isMovie: Value(isMovie),
            savedAt: Value(now),
          ),
        );
    // Optimistic state update - avoid the invalidateSelf rebuild flash.
    final current = state.value ?? const <String, TmdbOverride>{};
    state = AsyncData({
      ...current,
      contentId: TmdbOverride(
        contentId: contentId,
        sourceId: sourceId,
        tmdbId: tmdbId,
        isMovie: isMovie,
        savedAt: now,
      ),
    });
  }

  Future<void> remove({
    required String contentId,
    required String sourceId,
  }) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.tmdbOverrides)..where(
          (t) =>
              t.contentId.equals(contentId) & t.sourceId.equals(sourceId),
        ))
        .go();
    final current = state.value ?? const <String, TmdbOverride>{};
    final updated = Map<String, TmdbOverride>.from(current)
      ..remove(contentId);
    state = AsyncData(updated);
  }
}

final tmdbOverridesProvider = AsyncNotifierProvider<TmdbOverridesNotifier,
    Map<String, TmdbOverride>>(TmdbOverridesNotifier.new);
