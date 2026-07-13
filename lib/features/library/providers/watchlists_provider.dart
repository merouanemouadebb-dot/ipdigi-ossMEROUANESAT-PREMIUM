import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';

class Watchlist {
  final String id;
  final String name;
  final String? description;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Watchlist({
    required this.id,
    required this.name,
    this.description,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });
}

class WatchlistEntry {
  final String watchlistId;
  final String contentId;
  final String sourceId;
  final DateTime addedAt;
  const WatchlistEntry({
    required this.watchlistId,
    required this.contentId,
    required this.sourceId,
    required this.addedAt,
  });
}

class WatchlistItemsArgs {
  final String watchlistId;
  const WatchlistItemsArgs(this.watchlistId);
  @override
  bool operator ==(Object other) =>
      other is WatchlistItemsArgs && other.watchlistId == watchlistId;
  @override
  int get hashCode => watchlistId.hashCode;
}

class WatchlistsNotifier extends AsyncNotifier<List<Watchlist>> {
  @override
  Future<List<Watchlist>> build() async {
    final db = ref.watch(databaseProvider);
    final rows = await (db.select(db.watchlists)..orderBy([
              (t) => OrderingTerm(expression: t.position),
              (t) => OrderingTerm(expression: t.createdAt),
            ]))
        .get();
    return rows
        .map(
          (r) => Watchlist(
            id: r.id,
            name: r.name,
            description: r.description,
            position: r.position,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          ),
        )
        .toList();
  }

  Future<String> create({required String name, String? description}) async {
    final db = ref.read(databaseProvider);
    final id = _newId();
    final now = DateTime.now();
    final existing = state.value ?? const <Watchlist>[];
    final nextPos = existing.isEmpty
        ? 0
        : existing.map((e) => e.position).reduce(max) + 1;
    final cleanDesc = (description == null || description.trim().isEmpty)
        ? null
        : description.trim();
    await db.into(db.watchlists).insert(
          WatchlistsCompanion(
            id: Value(id),
            name: Value(name.trim()),
            description: Value(cleanDesc),
            position: Value(nextPos),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    // Optimistic state update - calling invalidateSelf would trigger a
    // rebuild and the widget tree would stay black for a frame (Riverpod
    // 3 AsyncNotifier behavior).
    state = AsyncData([
      ...existing,
      Watchlist(
        id: id,
        name: name.trim(),
        description: cleanDesc,
        position: nextPos,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    return id;
  }

  Future<void> updateList({
    required String id,
    required String name,
    String? description,
  }) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final cleanDesc = (description == null || description.trim().isEmpty)
        ? null
        : description.trim();
    await (db.update(db.watchlists)..where((t) => t.id.equals(id))).write(
      WatchlistsCompanion(
        name: Value(name.trim()),
        description: Value(cleanDesc),
        updatedAt: Value(now),
      ),
    );
    final existing = state.value ?? const <Watchlist>[];
    state = AsyncData(existing
        .map((w) => w.id != id
            ? w
            : Watchlist(
                id: w.id,
                name: name.trim(),
                description: cleanDesc,
                position: w.position,
                createdAt: w.createdAt,
                updatedAt: now,
              ))
        .toList());
  }

  Future<void> delete(String id) async {
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      await (db.delete(db.watchlistItems)
            ..where((t) => t.watchlistId.equals(id)))
          .go();
      await (db.delete(db.watchlists)..where((t) => t.id.equals(id))).go();
    });
    final existing = state.value ?? const <Watchlist>[];
    state = AsyncData(existing.where((w) => w.id != id).toList());
    // Refresh the items + containing families - this call doesn't dispose
    // its own notifier, so it's safe. We don't call invalidateSelf because
    // we already set the state above.
    ref.invalidate(watchlistItemsProvider);
    ref.invalidate(watchlistsContainingProvider);
  }

  Future<void> addItem({
    required String watchlistId,
    required String contentId,
    required String sourceId,
  }) async {
    final db = ref.read(databaseProvider);
    await db.into(db.watchlistItems).insertOnConflictUpdate(
          WatchlistItemsCompanion(
            watchlistId: Value(watchlistId),
            contentId: Value(contentId),
            sourceId: Value(sourceId),
            addedAt: Value(DateTime.now()),
          ),
        );
    // Invalidate for the item-level families - these providers are
    // FutureProvider.family, so invalidate is safe (no NotifierProvider
    // dispose drama).
    ref.invalidate(watchlistItemsProvider);
    ref.invalidate(watchlistsContainingProvider);
  }

  Future<void> removeItem({
    required String watchlistId,
    required String contentId,
    required String sourceId,
  }) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.watchlistItems)..where(
          (t) =>
              t.watchlistId.equals(watchlistId) &
              t.contentId.equals(contentId) &
              t.sourceId.equals(sourceId),
        ))
        .go();
    ref.invalidate(watchlistItemsProvider);
    ref.invalidate(watchlistsContainingProvider);
  }

  String _newId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

final watchlistsProvider =
    AsyncNotifierProvider<WatchlistsNotifier, List<Watchlist>>(
      WatchlistsNotifier.new,
    );

/// List contents - read-only family provider. For mutations, use the
/// main [watchlistsProvider]'s addItem / removeItem methods; they
/// invalidate the appropriate family.
final watchlistItemsProvider = FutureProvider.family<List<WatchlistEntry>,
    WatchlistItemsArgs>((ref, args) async {
  final db = ref.watch(databaseProvider);
  final rows = await (db.select(db.watchlistItems)
        ..where((t) => t.watchlistId.equals(args.watchlistId))
        ..orderBy([
          (t) => OrderingTerm(
                expression: t.addedAt,
                mode: OrderingMode.desc,
              ),
        ]))
      .get();
  return rows
      .map(
        (r) => WatchlistEntry(
          watchlistId: r.watchlistId,
          contentId: r.contentId,
          sourceId: r.sourceId,
          addedAt: r.addedAt,
        ),
      )
      .toList();
});

/// Which lists contain the given contentId?
final watchlistsContainingProvider =
    FutureProvider.family<Set<String>, String>((ref, contentId) async {
  final db = ref.watch(databaseProvider);
  final rows = await (db.select(db.watchlistItems)
        ..where((t) => t.contentId.equals(contentId)))
      .get();
  return rows.map((r) => r.watchlistId).toSet();
});
