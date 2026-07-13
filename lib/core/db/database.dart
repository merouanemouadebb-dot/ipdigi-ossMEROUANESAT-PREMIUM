import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
// ignore: unused_import
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../config/app_config.dart';
import '../../features/sources/domain/source.dart';

part 'database.g.dart';

class Sources extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // xtream | m3u | direct
  TextColumn get configJson => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CachedChannels extends Table {
  TextColumn get id => text()(); // composite key: sourceId|streamId
  TextColumn get sourceId => text()();
  TextColumn get streamId => text()();
  TextColumn get name => text()();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get streamUrl => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get categoryName => text().nullable()();
  TextColumn get kind => text()(); // live | movie | series
  TextColumn get plot => text().nullable()();
  TextColumn get backdropUrl => text().nullable()();
  IntColumn get year => integer().nullable()();
  RealColumn get rating => real().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get cachedAt => dateTime()();
  /// XMLTV channel id - Xtream returns this as `epg_channel_id` next
  /// to `stream_id`, and M3U sources carry it as the `tvg-id`
  /// attribute. Used by the EPG service to map a programme's
  /// `channel="..."` attribute back to the right MediaItem. Nullable
  /// because plenty of M3U channels ship without a tvg-id.
  TextColumn get epgChannelId => text().nullable()();
  /// The date the publisher added it to the catalogue. Comes from
  /// Xtream's `added` field. Used by the "Newly Added" sorting and the
  /// home page "Newly Added" row. Empty for M3U/Direct sources.
  DateTimeColumn get addedAt => dateTime().nullable()();
  /// Flat M3U series grouping link. Null for live, movies, series containers,
  /// and all Xtream rows. Set to the parent series container's streamId on
  /// M3U episode rows so the detail page can collect a series' episodes and
  /// the Series grid can hide raw episodes (it shows seriesId IS NULL only).
  TextColumn get seriesId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CachedDetails extends Table {
  TextColumn get id => text()(); // composite key: sourceId|streamId
  TextColumn get sourceId => text()();
  TextColumn get streamId => text()();
  TextColumn get kind => text()(); // movie | series
  TextColumn get castCsv => text().nullable()();
  TextColumn get directorsCsv => text().nullable()();
  TextColumn get genresCsv => text().nullable()();
  TextColumn get plot => text().nullable()();
  TextColumn get country => text().nullable()();
  IntColumn get runtimeSeconds => integer().nullable()();
  TextColumn get releaseDate => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get backdropUrl => text().nullable()();
  RealColumn get rating => real().nullable()();
  DateTimeColumn get cachedAt => dateTime()();
  /// Original title resolved from TMDB (e.g. the panel ships the Turkish
  /// title while TMDB has "The Dark Knight"). Search runs over both the
  /// panel name and original_title; detail pages also show the original
  /// title in italics below. Null means TMDB has not resolved it yet.
  TextColumn get originalTitle => text().nullable()();
  /// TMDB's localized title. The panel's `name` field is not always
  /// translated into the user's language, so we keep TMDB's localized
  /// title separately; the search index checks both at once.
  TextColumn get localizedTitle => text().nullable()();
  /// Comma-separated list of localized/original keywords from TMDB's
  /// `/keywords` output. The personalized recommender uses this for sharp
  /// signals like "alien-invasion" or "heist-gone-wrong"; the genre set
  /// alone left recommendations too broad.
  TextColumn get keywordsCsv => text().nullable()();
  /// TMDB `external_ids.imdb_id` - not used in the UI yet, but we keep it
  /// persisted for a future RT/Letterboxd integration, so we can match
  /// without a second TMDB roundtrip.
  TextColumn get imdbId => text().nullable()();
  /// TMDB movie/series id. A panel-independent universal id: the same
  /// movie has the same tmdbId across different panels. Rating/watch
  /// signals are merged on the read side through this id. Written once the
  /// TMDB lookup resolves (on detail open); null if unresolved.
  IntColumn get tmdbId => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Favorites extends Table {
  TextColumn get contentId => text()();
  TextColumn get sourceId => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {contentId, sourceId};
}

class WatchHistory extends Table {
  TextColumn get contentId => text()();
  TextColumn get sourceId => text()();
  TextColumn get parentId => text().nullable()();
  IntColumn get positionMs => integer()();
  IntColumn get durationMs => integer()();
  DateTimeColumn get lastWatchedAt => dateTime()();
  /// The real time (ms) the user spent in front of the player. Seeked
  /// seconds are not added to this counter. If `actualWatchMs / durationMs
  /// < 0.6` or seekForwardCount > 8, the UI and recommender treat it as
  /// "skimmed".
  IntColumn get actualWatchMs => integer().withDefault(const Constant(0))();
  /// Total number of forward seeks. Many forward jumps are a "skim"
  /// signal; the user is considered not to have consumed the content.
  IntColumn get seekForwardCount =>
      integer().withDefault(const Constant(0))();
  /// Total number of backward seeks. A rewatch or missed-dialogue signal;
  /// in the recommender it adds weight to the "may have liked it" side.
  IntColumn get seekBackwardCount =>
      integer().withDefault(const Constant(0))();
  /// Total seconds skipped forward (in ms). The second signal for the
  /// skimmed badge.
  IntColumn get seekForwardMs =>
      integer().withDefault(const Constant(0))();
  IntColumn get seekBackwardMs =>
      integer().withDefault(const Constant(0))();
  /// A short label like "S1E3" for series episodes. The watch history
  /// page shows it below the poster; instead of calling the series detail
  /// provider at runtime, we write it once during the player save. Stays
  /// null for movies.
  TextColumn get episodeLabel => text().nullable()();
  /// Panel category (e.g. "Action", "Turkish Movies"). Shown as a badge
  /// in the UI; we keep it denormalized the same way because the user may
  /// want to see history even for a deleted source.
  TextColumn get categoryName => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {contentId, sourceId};
}

/// The rating the user gave a piece of content (1.0 - 10.0, 0.5 step) and
/// an optional free-text comment. A core signal for recommendations: the
/// AI rec engine derives the user profile from these rows.
class UserRatings extends Table {
  TextColumn get contentId => text()();
  TextColumn get sourceId => text()();
  /// Series episodes can be rated separately; the root series rating has
  /// parentId=null. The UI currently shows only root rating, but the
  /// column is here so per-episode rating stays possible later.
  TextColumn get parentId => text().nullable()();
  RealColumn get score => real()(); // 1.0 - 10.0, 0.5 step
  TextColumn get comment => text().nullable()();
  DateTimeColumn get ratedAt => dateTime()();
  /// The TMDB id of the rated content (if any). Kept persisted alongside
  /// the rating so that even if the source is deleted and a different
  /// panel is added, the same-tmdbId movie in the new panel can be matched
  /// to this rating. Stays null if TMDB was unresolved at rating time.
  IntColumn get tmdbId => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {contentId, sourceId};
}

/// Watchlists created by the user. Free-form: the category is not fixed,
/// the user gives each list whatever name they want.
class Watchlists extends Table {
  TextColumn get id => text()(); // uuid v4
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// TMDB matches manually corrected by the user. When the IPTV panel
/// labels a movie "Concussion" and gives no year, the automatic lookup
/// can pick the wrong version; the user picks the right one from the
/// detail page via "Wrong movie?" → TMDB picker, and this table holds the
/// fixed match for that composite item-id.
class TmdbOverrides extends Table {
  TextColumn get contentId => text()(); // composite: sourceId|streamId
  TextColumn get sourceId => text()();
  IntColumn get tmdbId => integer()();
  BoolColumn get isMovie => boolean()();
  DateTimeColumn get savedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {contentId, sourceId};
}

/// List items. Ordered by `addedAt` desc so newly added items can be
/// shown at the top.
class WatchlistItems extends Table {
  TextColumn get watchlistId => text()();
  TextColumn get contentId => text()();
  TextColumn get sourceId => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {watchlistId, contentId, sourceId};
}

/// Persisted XMLTV programmes. Keyed by (sourceId, channelId, start)
/// so we can replace a channel's schedule atomically without losing
/// programmes for other channels in the same source. Surviving an
/// app restart saves the multi-MB XMLTV redownload on cold start.
@DataClassName('EpgProgramRow')
class EpgPrograms extends Table {
  TextColumn get sourceId => text()();
  TextColumn get channelId => text()();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get stop => dateTime()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get categoriesCsv => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {sourceId, channelId, start};
}

@DriftDatabase(
  tables: [
    Sources,
    CachedChannels,
    CachedDetails,
    Favorites,
    WatchHistory,
    EpgPrograms,
    UserRatings,
    Watchlists,
    WatchlistItems,
    TmdbOverrides,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(watchHistory, watchHistory.parentId);
          }
          if (from < 3) {
            await m.addColumn(cachedChannels, cachedChannels.position);
            await m.createTable(cachedDetails);
          }
          if (from < 4) {
            await m.addColumn(cachedChannels, cachedChannels.epgChannelId);
          }
          if (from < 5) {
            await m.createTable(epgPrograms);
          }
          if (from < 6) {
            await m.addColumn(cachedChannels, cachedChannels.addedAt);
          }
          if (from < 7) {
            // We keep TMDB metadata persisted so the search index can
            // also match on the original + localized title.
            await m.addColumn(cachedDetails, cachedDetails.originalTitle);
            await m.addColumn(cachedDetails, cachedDetails.localizedTitle);
          }
          if (from < 8) {
            // v8: rating + watchlist + enriched watch history.
            await m.addColumn(watchHistory, watchHistory.actualWatchMs);
            await m.addColumn(watchHistory, watchHistory.seekForwardCount);
            await m.addColumn(watchHistory, watchHistory.seekBackwardCount);
            await m.addColumn(watchHistory, watchHistory.seekForwardMs);
            await m.addColumn(watchHistory, watchHistory.seekBackwardMs);
            await m.addColumn(cachedDetails, cachedDetails.keywordsCsv);
            await m.addColumn(cachedDetails, cachedDetails.imdbId);
            await m.createTable(userRatings);
            await m.createTable(watchlists);
            await m.createTable(watchlistItems);
          }
          if (from < 9) {
            // v9: watch history UI became a poster grid; the series
            // episode label and category name are kept denormalized.
            await m.addColumn(watchHistory, watchHistory.episodeLabel);
            await m.addColumn(watchHistory, watchHistory.categoryName);
          }
          if (from < 10) {
            // v10: the user's manual TMDB match.
            await m.createTable(tmdbOverrides);
          }
          if (from < 11) {
            // v11: group key that ties flat M3U series episodes to their
            // series. Idempotent: the column may already have been added
            // by a previous half-finished migration (if the app closed
            // before user_version was committed). In that case drift throws
            // "duplicate column" and DB open deadlocks in the background
            // isolate, leaving the app stuck on an infinite spinner. Skip
            // the step silently if the column already exists.
            await _addColumnIfMissing(
              () => m.addColumn(cachedChannels, cachedChannels.seriesId),
            );
          }
          if (from < 12) {
            // v12: source id is now deterministic (see
            // IptvSource.deterministicId). Old random (v4) source UUIDs are
            // remapped to the deterministic id, so deleting and re-adding a
            // source does not detach rating/watch history/favorite/watchlist.
            // In a single transaction, idempotent (second run is a no-op).
            await _remapToDeterministicSourceIds(m);
          }
          if (from < 13) {
            // v13: panel-independent TMDB id. A tmdbId column on rating and
            // catalog detail - so the same movie matches across panels too.
            await _addColumnIfMissing(
              () => m.addColumn(cachedDetails, cachedDetails.tmdbId),
            );
            await _addColumnIfMissing(
              () => m.addColumn(userRatings, userRatings.tmdbId),
            );
          }
        },
      );

  /// Moves old random `sourceId` UUIDs to the stable id derived via
  /// [IptvSource.deterministicId]. Because the content id is a
  /// `sourceId|streamId` composite and `streamId` is a panel/playlist
  /// constant, fixing the single variable `sourceId` reattaches all side
  /// table records (rating, favorite, history, watchlist, override) to the
  /// old content.
  static Future<void> _remapToDeterministicSourceIds(Migrator m) async {
    final db = m.database;
    final rows = await db
        .customSelect('SELECT id, type, config_json FROM sources')
        .get();
    for (final row in rows) {
      final oldId = row.read<String>('id');
      final type = row.read<String>('type');
      final configJson = row.read<String>('config_json');
      String newId;
      try {
        final kind = SourceKind.values.byName(type);
        final config = jsonDecode(configJson) as Map<String, dynamic>;
        newId = IptvSource.deterministicId(kind: kind, config: config);
      } catch (_) {
        continue; // leave a source that cannot be parsed as-is
      }
      if (newId == oldId) continue;
      // If the target id already exists (two sources resolving to the same
      // panel), skip moving this record to avoid a clash - no data loss.
      final clash = await db.customSelect(
        'SELECT 1 FROM sources WHERE id = ? LIMIT 1',
        variables: [Variable<String>(newId)],
      ).get();
      if (clash.isNotEmpty) continue;

      await db.customStatement(
        'UPDATE sources SET id = ? WHERE id = ?',
        [newId, oldId],
      );
      // Catalog tables: change the sourceId prefix of the composite id.
      await db.customStatement(
        "UPDATE cached_channels SET id = ? || '|' || stream_id, "
        'source_id = ? WHERE source_id = ?',
        [newId, newId, oldId],
      );
      await db.customStatement(
        "UPDATE cached_details SET id = ? || '|' || stream_id, "
        'source_id = ? WHERE source_id = ?',
        [newId, newId, oldId],
      );
      // User signal tables: content_id is composite, |streamId is kept.
      for (final t in const [
        'user_ratings',
        'favorites',
        'watch_history',
        'watchlist_items',
        'tmdb_overrides',
      ]) {
        await db.customStatement(
          'UPDATE $t SET source_id = ?, '
          "content_id = ? || substr(content_id, instr(content_id, '|')) "
          "WHERE source_id = ? AND instr(content_id, '|') > 0",
          [newId, newId, oldId],
        );
      }
      // Series episodes' parent_id is composite too; source_id is now newId.
      await db.customStatement(
        'UPDATE watch_history SET '
        "parent_id = ? || substr(parent_id, instr(parent_id, '|')) "
        'WHERE source_id = ? AND parent_id IS NOT NULL '
        "AND instr(parent_id, '|') > 0",
        [newId, newId],
      );
      await db.customStatement(
        'UPDATE epg_programs SET source_id = ? WHERE source_id = ?',
        [newId, oldId],
      );
    }

    // Second stage: recover user signals whose source was DELETED (orphan).
    // If the user deleted an old source and re-added the same panel with a
    // new (now deterministic) id, the old rating/favorite/watchlist is still
    // tied to the deleted source's UUID. Because the streamId in content_id
    // is a panel constant, we find the row with the same streamId in the
    // current catalog and reattach there. `UPDATE OR IGNORE`: if the target
    // composite is already recorded (duplicate), it skips that row silently
    // instead of hitting a PK clash.
    for (final t in const [
      'user_ratings',
      'favorites',
      'watch_history',
      'watchlist_items',
      'tmdb_overrides',
    ]) {
      await db.customStatement(
        'UPDATE OR IGNORE $t SET '
        'content_id = (SELECT c.id FROM cached_channels c WHERE c.stream_id = '
        "  substr($t.content_id, instr($t.content_id, '|') + 1) LIMIT 1), "
        'source_id = (SELECT c.source_id FROM cached_channels c WHERE '
        "  c.stream_id = substr($t.content_id, instr($t.content_id, '|') + 1) "
        '  LIMIT 1) '
        'WHERE source_id NOT IN (SELECT id FROM sources) '
        "AND instr(content_id, '|') > 0 "
        'AND EXISTS (SELECT 1 FROM cached_channels c WHERE c.stream_id = '
        "  substr($t.content_id, instr($t.content_id, '|') + 1))",
      );
    }
  }

  /// Runs drift's `addColumn`, swallowing the "duplicate column" error if
  /// the column already exists. Prevents a half-finished migration from
  /// permanently locking the app. Any other error is rethrown.
  static Future<void> _addColumnIfMissing(
    Future<void> Function() add,
  ) async {
    try {
      await add();
    } on Object catch (e) {
      if (!e.toString().toLowerCase().contains('duplicate column')) {
        rethrow;
      }
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, '${AppConfig.I.storageSlug}.sqlite'));
    final cacheBase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cacheBase;
    return NativeDatabase.createInBackground(file);
  });
}
