import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/demo/demo_mode.dart';

class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  /// Set elements are `MediaItem.id` (composite "sourceId|streamId").
  @override
  Future<Set<String>> build() async {
    // Demo mode short-circuit: don't touch the real DB, return the
    // hardcoded favorites list from the demo catalog.
    final demo = ref.watch(demoModeProvider).value;
    if (demo != null && demo.active) {
      return demo.favorites;
    }
    final db = ref.watch(databaseProvider);
    final rows = await db.select(db.favorites).get();
    return rows.map((r) => r.contentId).toSet();
  }

  Future<void> toggle(String sourceId, String contentId) async {
    final db = ref.read(databaseProvider);
    final current = state.value ?? <String>{};
    final wasFav = current.contains(contentId);
    if (wasFav) {
      await (db.delete(db.favorites)..where(
            (t) => t.contentId.equals(contentId) & t.sourceId.equals(sourceId),
          ))
          .go();
    } else {
      await db
          .into(db.favorites)
          .insertOnConflictUpdate(
            FavoritesCompanion(
              contentId: Value(contentId),
              sourceId: Value(sourceId),
              addedAt: Value(DateTime.now()),
            ),
          );
    }
    // Calling invalidateSelf triggers an AsyncNotifier rebuild, the
    // widget tree disposes for one frame and the user sees a black
    // screen (Riverpod 3 behavior). With an optimistic update we update
    // the state synchronously - no rebuild, instant UI.
    final updated = {...current};
    if (wasFav) {
      updated.remove(contentId);
    } else {
      updated.add(contentId);
    }
    state = AsyncData(updated);
  }
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);

class HistoryEntry {
  final String contentId;
  final String sourceId;
  final String? parentId;
  final Duration position;
  final Duration duration;
  final DateTime lastWatchedAt;
  /// The actual time the user spent in front of the player. Seconds
  /// skipped over by seeks are not counted here; the core signal for the
  /// "skimmed" badge.
  final Duration actualWatch;
  final int seekForwardCount;
  final int seekBackwardCount;
  final Duration seekForwardJump;
  final Duration seekBackwardJump;
  /// A label like "S1E3" for series episodes. Null for movies.
  final String? episodeLabel;
  /// Panel category (e.g. "Action"). Denormalized so that orphan records
  /// whose source has been deleted keep a visible label.
  final String? categoryName;
  const HistoryEntry({
    required this.contentId,
    required this.sourceId,
    required this.position,
    required this.duration,
    required this.lastWatchedAt,
    this.parentId,
    this.actualWatch = Duration.zero,
    this.seekForwardCount = 0,
    this.seekBackwardCount = 0,
    this.seekForwardJump = Duration.zero,
    this.seekBackwardJump = Duration.zero,
    this.episodeLabel,
    this.categoryName,
  });

  double get progress => duration.inMilliseconds == 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);

  /// "skimmed" signal: actual watch time is less than 60% of the content
  /// or there are more than 8 forward seeks. The UI shows a badge, the
  /// recommender applies a negative weight.
  bool get isSkimmed {
    if (duration.inMilliseconds <= 0) return false;
    if (seekForwardCount > 8) return true;
    if (actualWatch.inMilliseconds == 0) return false;
    final ratio = actualWatch.inMilliseconds / duration.inMilliseconds;
    return ratio < 0.6 && progress > 0.4;
  }

  /// Counted as completed: progress is 95%+ and not skimmed.
  bool get isCompleted => progress >= 0.95 && !isSkimmed;

  double get actualRatio => duration.inMilliseconds == 0
      ? 0
      : (actualWatch.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
}

class HistoryNotifier extends AsyncNotifier<List<HistoryEntry>> {
  @override
  Future<List<HistoryEntry>> build() async {
    // Demo mode short-circuit: don't touch the real DB, return the fake
    // history list prepared in the demo state. The Continue Watching row,
    // Watch History page and recommender all fill in automatically.
    final demo = ref.watch(demoModeProvider).value;
    if (demo != null && demo.active) {
      return demo.history;
    }
    final db = ref.watch(databaseProvider);
    final rows =
        await (db.select(db.watchHistory)..orderBy([
              (t) => OrderingTerm(
                expression: t.lastWatchedAt,
                mode: OrderingMode.desc,
              ),
            ]))
            .get();
    return rows
        .map(
          (r) => HistoryEntry(
            contentId: r.contentId,
            sourceId: r.sourceId,
            parentId: r.parentId,
            position: Duration(milliseconds: r.positionMs),
            duration: Duration(milliseconds: r.durationMs),
            lastWatchedAt: r.lastWatchedAt,
            actualWatch: Duration(milliseconds: r.actualWatchMs),
            seekForwardCount: r.seekForwardCount,
            seekBackwardCount: r.seekBackwardCount,
            seekForwardJump: Duration(milliseconds: r.seekForwardMs),
            seekBackwardJump: Duration(milliseconds: r.seekBackwardMs),
            episodeLabel: r.episodeLabel,
            categoryName: r.categoryName,
          ),
        )
        .toList();
  }

  Future<void> save({
    required String sourceId,
    required String contentId,
    required Duration position,
    required Duration duration,
    String? parentId,
    Duration? actualWatch,
    int? seekForwardCount,
    int? seekBackwardCount,
    Duration? seekForwardJump,
    Duration? seekBackwardJump,
    String? episodeLabel,
    String? categoryName,
  }) async {
    final db = ref.read(databaseProvider);
    // Read the existing row - the seek counters and actualWatch must
    // ACCUMULATE on top of the past session; if we set them from scratch
    // on every save we lose the signal built up across multiple player sessions.
    final existing = await (db.select(db.watchHistory)..where(
          (t) => t.contentId.equals(contentId) & t.sourceId.equals(sourceId),
        ))
        .getSingleOrNull();
    await db
        .into(db.watchHistory)
        .insertOnConflictUpdate(
          WatchHistoryCompanion(
            contentId: Value(contentId),
            sourceId: Value(sourceId),
            parentId: Value(parentId),
            positionMs: Value(position.inMilliseconds),
            durationMs: Value(duration.inMilliseconds),
            lastWatchedAt: Value(DateTime.now()),
            actualWatchMs: actualWatch == null
                ? Value(existing?.actualWatchMs ?? 0)
                : Value(
                    (existing?.actualWatchMs ?? 0) + actualWatch.inMilliseconds,
                  ),
            seekForwardCount: seekForwardCount == null
                ? Value(existing?.seekForwardCount ?? 0)
                : Value(
                    (existing?.seekForwardCount ?? 0) + seekForwardCount,
                  ),
            seekBackwardCount: seekBackwardCount == null
                ? Value(existing?.seekBackwardCount ?? 0)
                : Value(
                    (existing?.seekBackwardCount ?? 0) + seekBackwardCount,
                  ),
            seekForwardMs: seekForwardJump == null
                ? Value(existing?.seekForwardMs ?? 0)
                : Value(
                    (existing?.seekForwardMs ?? 0) +
                        seekForwardJump.inMilliseconds,
                  ),
            seekBackwardMs: seekBackwardJump == null
                ? Value(existing?.seekBackwardMs ?? 0)
                : Value(
                    (existing?.seekBackwardMs ?? 0) +
                        seekBackwardJump.inMilliseconds,
                  ),
            episodeLabel: episodeLabel == null
                ? Value(existing?.episodeLabel)
                : Value(episodeLabel),
            categoryName: categoryName == null
                ? Value(existing?.categoryName)
                : Value(categoryName),
          ),
        );
    // Optimistic state update: fold the written row into the in-memory
    // state. Calling invalidateSelf would rebuild the AsyncNotifier and
    // cause a one-frame black-screen flash.
    final newEntry = HistoryEntry(
      contentId: contentId,
      sourceId: sourceId,
      parentId: parentId,
      position: position,
      duration: duration,
      lastWatchedAt: DateTime.now(),
      actualWatch: Duration(
        milliseconds: (existing?.actualWatchMs ?? 0) +
            (actualWatch?.inMilliseconds ?? 0),
      ),
      seekForwardCount:
          (existing?.seekForwardCount ?? 0) + (seekForwardCount ?? 0),
      seekBackwardCount:
          (existing?.seekBackwardCount ?? 0) + (seekBackwardCount ?? 0),
      seekForwardJump: Duration(
        milliseconds: (existing?.seekForwardMs ?? 0) +
            (seekForwardJump?.inMilliseconds ?? 0),
      ),
      seekBackwardJump: Duration(
        milliseconds: (existing?.seekBackwardMs ?? 0) +
            (seekBackwardJump?.inMilliseconds ?? 0),
      ),
      episodeLabel: episodeLabel ?? existing?.episodeLabel,
      categoryName: categoryName ?? existing?.categoryName,
    );
    final current = state.value ?? const <HistoryEntry>[];
    final filtered = current
        .where((h) =>
            !(h.contentId == contentId && h.sourceId == sourceId))
        .toList();
    state = AsyncData([newEntry, ...filtered]);
  }

  /// Clears the entire watch history. For the "Clear All" on the History
  /// page. Instead of invalidateSelf we set the state synchronously -
  /// otherwise the widget tree disposes for one frame during the
  /// AsyncNotifier rebuild and the UI shows a black-screen flash.
  Future<void> clearAll() async {
    final db = ref.read(databaseProvider);
    await db.delete(db.watchHistory).go();
    state = const AsyncData(<HistoryEntry>[]);
  }

  Future<void> remove({
    required String sourceId,
    required String contentId,
  }) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.watchHistory)..where(
          (t) => t.contentId.equals(contentId) & t.sourceId.equals(sourceId),
        ))
        .go();
    final current = state.value ?? const <HistoryEntry>[];
    state = AsyncData(
      current
          .where((h) =>
              !(h.contentId == contentId && h.sourceId == sourceId))
          .toList(),
    );
  }

  /// Removes every history row for a parent (series) and the individual
  /// content row itself. Used by the "remove from Continue" affordance.
  Future<void> removeForContent({
    required String sourceId,
    required String contentId,
  }) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.watchHistory)..where(
          (t) =>
              t.sourceId.equals(sourceId) &
              (t.contentId.equals(contentId) | t.parentId.equals(contentId)),
        ))
        .go();
    final current = state.value ?? const <HistoryEntry>[];
    state = AsyncData(
      current
          .where((h) =>
              h.sourceId != sourceId ||
              (h.contentId != contentId && h.parentId != contentId))
          .toList(),
    );
  }

  Future<HistoryEntry?> getEntry(String sourceId, String contentId) async {
    final db = ref.read(databaseProvider);
    final row =
        await (db.select(db.watchHistory)..where(
              (t) =>
                  t.contentId.equals(contentId) & t.sourceId.equals(sourceId),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return HistoryEntry(
      contentId: row.contentId,
      sourceId: row.sourceId,
      parentId: row.parentId,
      position: Duration(milliseconds: row.positionMs),
      duration: Duration(milliseconds: row.durationMs),
      lastWatchedAt: row.lastWatchedAt,
      actualWatch: Duration(milliseconds: row.actualWatchMs),
      seekForwardCount: row.seekForwardCount,
      seekBackwardCount: row.seekBackwardCount,
      seekForwardJump: Duration(milliseconds: row.seekForwardMs),
      seekBackwardJump: Duration(milliseconds: row.seekBackwardMs),
      episodeLabel: row.episodeLabel,
      categoryName: row.categoryName,
    );
  }
}

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<HistoryEntry>>(
      HistoryNotifier.new,
    );
