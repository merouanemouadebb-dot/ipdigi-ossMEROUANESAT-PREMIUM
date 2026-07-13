import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../epg/domain/epg_program.dart';
import '../../epg/providers/epg_provider.dart';
import '../../library/providers/library_provider.dart';
import '../../player/presentation/player_page.dart';
import '../../settings/providers/adult_filter_provider.dart';
import '../../sources/domain/media_item.dart';

const double _kCardWidth = 280;
const double _kCardHeight = 158;
const double _kHeroHeight = 320;
const Duration _kSoonWindow = Duration(minutes: 60);

/// Live TV → Discover tab. A discovery surface that answers the "what
/// should I watch" question within 5 seconds. Hero spotlight + 4 rows.
///
/// Data flow: as long as the `epgProvider` snapshot and the liveChannels
/// reference stay stable, every query returns from a cached lookup. The
/// minute tick updates `_now` and refreshes the isLive states.
class DiscoverTab extends ConsumerStatefulWidget {
  final List<MediaItem> liveChannels;
  const DiscoverTab({super.key, required this.liveChannels});

  @override
  ConsumerState<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<DiscoverTab> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  // Hero spotlight stays fixed for the session. Pick a new one when the
  // program ends. The first pick happens in build (providers hold no value
  // yet in initState), so it's lazy: set on the first build.
  MediaItem? _heroChannel;
  EpgProgram? _heroProgram;
  bool _heroLocked = false;

  _DiscoverData? _cache;
  int? _cacheEpgIdent;
  int? _cacheItemsIdent;
  int? _cacheFavIdent;
  int? _cacheHistoryIdent;
  int? _cacheNowMinute;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    final until = Duration(seconds: 60 - n.second);
    Future.delayed(until, () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(epgProvider).value;
    final favorites = ref.watch(favoritesProvider).value ?? const <String>{};
    final history = ref.watch(historyProvider).value ?? const <HistoryEntry>[];

    if (snap == null || snap.bySource.isEmpty) {
      return _NoEpgState();
    }

    _ensureCache(snap, favorites, history);
    _ensureHero(snap, favorites, history);

    final data = _cache!;
    if (data.nowList.isEmpty &&
        data.soonList.isEmpty &&
        data.favoritesNow.isEmpty &&
        data.forYou.isEmpty &&
        _heroChannel == null) {
      return _EmptyEpgPrograms();
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        if (_heroChannel != null && _heroProgram != null)
          _HeroSpotlight(
            channel: _heroChannel!,
            program: _heroProgram!,
            now: _now,
            onPlay: () => _openChannel(_heroChannel!),
          ),
        const SizedBox(height: 12),
        if (data.nowList.isNotEmpty)
          _Row(
            title: ref.tr('live.discoverNow'),
            items: data.nowList,
            variant: _CardVariant.now,
            now: _now,
            nowMap: data.nowByItemId,
            nextMap: data.nextByItemId,
            onTap: _openChannel,
          ),
        if (data.soonList.isNotEmpty)
          _Row(
            title: ref.tr('live.discoverSoon'),
            items: data.soonList,
            variant: _CardVariant.soon,
            now: _now,
            nowMap: data.nowByItemId,
            nextMap: data.nextByItemId,
            onTap: _openChannel,
          ),
        if (data.favoritesNow.isNotEmpty)
          _Row(
            title: ref.tr('live.discoverFavorites'),
            items: data.favoritesNow,
            variant: _CardVariant.favorite,
            now: _now,
            nowMap: data.nowByItemId,
            nextMap: data.nextByItemId,
            onTap: _openChannel,
          ),
        if (data.recentList.isNotEmpty)
          _Row(
            title: ref.tr('live.discoverRecent'),
            items: data.recentList,
            variant: _CardVariant.now,
            now: _now,
            nowMap: data.nowByItemId,
            nextMap: data.nextByItemId,
            onTap: _openChannel,
          ),
        if (data.mostWatchedList.isNotEmpty)
          _Row(
            title: ref.tr('live.discoverMostWatched'),
            items: data.mostWatchedList,
            variant: _CardVariant.now,
            now: _now,
            nowMap: data.nowByItemId,
            nextMap: data.nextByItemId,
            onTap: _openChannel,
          ),
        if (data.eveningList.isNotEmpty)
          _Row(
            title: ref.tr('live.discoverEvening'),
            items: data.eveningList,
            variant: _CardVariant.soon,
            now: _now,
            nowMap: data.nowByItemId,
            nextMap: data.eveningProgramByItemId,
            onTap: _openChannel,
          ),
        if (data.forYou.isNotEmpty)
          _Row(
            title: ref.tr('live.discoverForYou'),
            items: data.forYou,
            variant: _CardVariant.now,
            now: _now,
            nowMap: data.nowByItemId,
            nextMap: data.nextByItemId,
            onTap: _openChannel,
          ),
        if (data.sportNow.isNotEmpty)
          _Row(
            title: ref.tr('live.discoverSportNow'),
            items: data.sportNow,
            variant: _CardVariant.now,
            now: _now,
            nowMap: data.nowByItemId,
            nextMap: data.nextByItemId,
            onTap: _openChannel,
          ),
        if (data.newsNow.isNotEmpty)
          _Row(
            title: ref.tr('live.discoverNewsNow'),
            items: data.newsNow,
            variant: _CardVariant.now,
            now: _now,
            nowMap: data.nowByItemId,
            nextMap: data.nextByItemId,
            onTap: _openChannel,
          ),
        if (data.docsNow.isNotEmpty)
          _Row(
            title: ref.tr('live.discoverDocsNow'),
            items: data.docsNow,
            variant: _CardVariant.now,
            now: _now,
            nowMap: data.nowByItemId,
            nextMap: data.nextByItemId,
            onTap: _openChannel,
          ),
        if (data.kidsNow.isNotEmpty)
          _Row(
            title: ref.tr('live.discoverKidsNow'),
            items: data.kidsNow,
            variant: _CardVariant.now,
            now: _now,
            nowMap: data.nowByItemId,
            nextMap: data.nextByItemId,
            onTap: _openChannel,
          ),
        if (data.musicNow.isNotEmpty)
          _Row(
            title: ref.tr('live.discoverMusicNow'),
            items: data.musicNow,
            variant: _CardVariant.now,
            now: _now,
            nowMap: data.nowByItemId,
            nextMap: data.nextByItemId,
            onTap: _openChannel,
          ),
        if (data.newlyAddedList.isNotEmpty)
          _Row(
            title: ref.tr('live.discoverNewlyAdded'),
            items: data.newlyAddedList,
            variant: _CardVariant.now,
            now: _now,
            nowMap: data.nowByItemId,
            nextMap: data.nextByItemId,
            onTap: _openChannel,
          ),
      ],
    );
  }

  void _openChannel(MediaItem item) {
    GoRouter.of(context).pushOnce(
      '/player',
      extra: PlayerArgs(item: item, isLive: true, startAt: Duration.zero),
    );
  }

  /// Derived cache - a single scan over every channel entering the window.
  /// A 17K-channel × isLive lookup was expensive; with the identity check
  /// it recomputes once a minute and returns the same cache in between.
  void _ensureCache(
    EpgSnapshot snap,
    Set<String> favorites,
    List<HistoryEntry> history,
  ) {
    final epgIdent = identityHashCode(snap);
    final itemsIdent = identityHashCode(widget.liveChannels);
    final favIdent = identityHashCode(favorites);
    final historyIdent = identityHashCode(history);
    final nowMinute = _now.millisecondsSinceEpoch ~/ 60000;

    if (_cache != null &&
        _cacheEpgIdent == epgIdent &&
        _cacheItemsIdent == itemsIdent &&
        _cacheFavIdent == favIdent &&
        _cacheHistoryIdent == historyIdent &&
        _cacheNowMinute == nowMinute) {
      return;
    }

    final nowByItemId = <String, EpgProgram>{};
    final nextByItemId = <String, EpgProgram>{};
    final safeChannels = <MediaItem>[];
    for (final c in widget.liveChannels) {
      if (isAdult(c)) continue;
      safeChannels.add(c);
      final cid = c.epgChannelId ?? c.streamId;
      final now = snap.nowPlaying(c.sourceId, cid, _now);
      if (now != null) {
        nowByItemId[c.id] = now;
      } else if (c.epgChannelId != null) {
        // Some panels don't match on small channelId ↔ streamId differences.
        final alt = snap.nowPlaying(c.sourceId, c.streamId, _now);
        if (alt != null) nowByItemId[c.id] = alt;
      }
      final next = snap.nextProgram(c.sourceId, cid, _now);
      if (next != null && next.start.isBefore(_now.add(_kSoonWindow))) {
        nextByItemId[c.id] = next;
      }
    }

    // History frequency: count live channels via contentId.
    final historyFreq = <String, int>{};
    for (final h in history) {
      historyFreq.update(h.contentId, (v) => v + 1, ifAbsent: () => 1);
    }

    // Live-now list: favorites first → history frequency → original order.
    final nowList = safeChannels
        .where((c) => nowByItemId.containsKey(c.id))
        .toList();
    nowList.sort((a, b) {
      final fa = favorites.contains(a.id) ? 0 : 1;
      final fb = favorites.contains(b.id) ? 0 : 1;
      if (fa != fb) return fa.compareTo(fb);
      final ha = historyFreq[a.id] ?? 0;
      final hb = historyFreq[b.id] ?? 0;
      if (ha != hb) return hb.compareTo(ha);
      return 0; // stable
    });

    // Starting soon: start ASC, first 30.
    final soonList = safeChannels
        .where((c) => nextByItemId.containsKey(c.id))
        .toList();
    soonList.sort(
      (a, b) => nextByItemId[a.id]!.start.compareTo(nextByItemId[b.id]!.start),
    );

    // Favorites now: the favorite subset of nowList (order preserved).
    final favoritesNow = nowList
        .where((c) => favorites.contains(c.id))
        .toList();

    // For you: top categories in history → matches that are live now.
    // History channel contentId → MediaItem lookup.
    final channelById = {for (final c in safeChannels) c.id: c};
    final categoryFreq = <String, int>{};
    for (final h in history) {
      final item = channelById[h.contentId];
      if (item == null) continue;
      final tokens = _categoryTokens(item.categoryName);
      for (final t in tokens) {
        categoryFreq.update(t, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    final topTokens = categoryFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final pickedTokens = topTokens.take(2).map((e) => e.key).toSet();
    List<MediaItem> forYou;
    if (pickedTokens.isEmpty) {
      // Cold start: TR allowlist + popular channel names.
      forYou = nowList
          .where((c) => _isLikelyTrPopular(c))
          .where((c) => !favorites.contains(c.id))
          .take(20)
          .toList();
    } else {
      final favIds = favoritesNow.map((c) => c.id).toSet();
      forYou = nowList
          .where((c) {
            if (favIds.contains(c.id)) return false;
            final ct = _categoryTokens(c.categoryName);
            return ct.any(pickedTokens.contains);
          })
          .take(20)
          .toList();
    }

    // Recently watched: live history newest lastWatchedAt → contentId,
    // matched with what's live now. When the same channel appears more
    // than once, the first (newest) instance is kept.
    final recentSeen = <String>{};
    final recentList = <MediaItem>[];
    for (final h in history) {
      if (recentSeen.contains(h.contentId)) continue;
      final c = channelById[h.contentId];
      if (c == null) continue;
      if (!nowByItemId.containsKey(c.id)) continue;
      recentSeen.add(h.contentId);
      recentList.add(c);
      if (recentList.length >= 20) break;
    }

    // Most watched: history frequency desc, the ones live now.
    final mostWatchedRanked = historyFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mostWatchedList = <MediaItem>[];
    final mostWatchedSeen = <String>{};
    for (final entry in mostWatchedRanked) {
      final c = channelById[entry.key];
      if (c == null) continue;
      if (!nowByItemId.containsKey(c.id)) continue;
      if (!mostWatchedSeen.add(c.id)) continue;
      mostWatchedList.add(c);
      if (mostWatchedList.length >= 20) break;
    }

    // Evening picks: programs starting today/tomorrow between 19:00-23:59.
    // No 60-min limit; the window is "tonight", the whole evening.
    final eveningStart = _eveningStart(_now);
    final eveningEnd = eveningStart.add(const Duration(hours: 5));
    final eveningProgramByItemId = <String, EpgProgram>{};
    final eveningCandidates = <MediaItem>[];
    if (eveningEnd.isAfter(_now)) {
      for (final c in safeChannels) {
        final cid = c.epgChannelId ?? c.streamId;
        final list = snap.bySource[c.sourceId]?[cid];
        if (list == null) continue;
        // List sorted by start. First program after eveningStart.
        EpgProgram? hit;
        for (final p in list) {
          if (p.start.isBefore(eveningStart)) continue;
          if (!p.start.isBefore(eveningEnd)) break;
          hit = p;
          break;
        }
        if (hit != null) {
          eveningProgramByItemId[c.id] = hit;
          eveningCandidates.add(c);
        }
      }
    }
    // Sort: favorite → history frequency → original.
    eveningCandidates.sort((a, b) {
      final fa = favorites.contains(a.id) ? 0 : 1;
      final fb = favorites.contains(b.id) ? 0 : 1;
      if (fa != fb) return fa.compareTo(fb);
      final ha = historyFreq[a.id] ?? 0;
      final hb = historyFreq[b.id] ?? 0;
      return hb.compareTo(ha);
    });

    // Newly added channels: MediaItem.addedAt desc, live now.
    final newlyAddedList = safeChannels
        .where((c) => c.addedAt != null && nowByItemId.containsKey(c.id))
        .toList();
    newlyAddedList.sort((a, b) => b.addedAt!.compareTo(a.addedAt!));

    // Genre rows: filter from nowList by category token.
    List<MediaItem> byToken(String tok) {
      final out = <MediaItem>[];
      for (final c in nowList) {
        final tokens = _categoryTokens(c.categoryName);
        // The program category could also be checked, but the M3U group-title
        // is usually enough; the EPG category text is multi-language and noisy.
        if (tokens.contains(tok)) out.add(c);
        if (out.length >= 20) break;
      }
      return out;
    }

    _cache = _DiscoverData(
      nowByItemId: nowByItemId,
      nextByItemId: nextByItemId,
      nowList: nowList.take(40).toList(),
      soonList: soonList.take(30).toList(),
      favoritesNow: favoritesNow.take(20).toList(),
      recentList: recentList,
      mostWatchedList: mostWatchedList,
      forYou: forYou,
      eveningList: eveningCandidates.take(20).toList(),
      newlyAddedList: newlyAddedList.take(20).toList(),
      sportNow: byToken('spor'),
      newsNow: byToken('haber'),
      docsNow: byToken('belgesel'),
      kidsNow: byToken('cocuk'),
      musicNow: byToken('muzik'),
      eveningProgramByItemId: eveningProgramByItemId,
    );
    _cacheEpgIdent = epgIdent;
    _cacheItemsIdent = itemsIdent;
    _cacheFavIdent = favIdent;
    _cacheHistoryIdent = historyIdent;
    _cacheNowMinute = nowMinute;
  }

  /// Hero fixed for the session. Re-pick when the program ends or it was
  /// never set. Priority: favorite + live + rich metadata → top history
  /// channel + live → TR popular fallback → any live one.
  void _ensureHero(
    EpgSnapshot snap,
    Set<String> favorites,
    List<HistoryEntry> history,
  ) {
    final stillValid =
        _heroProgram != null &&
        _heroChannel != null &&
        _heroProgram!.stop.isAfter(_now) &&
        _heroLocked;
    if (stillValid) return;

    final data = _cache!;
    MediaItem? pick;

    // 1. Favorite + live + preferably a rich description
    final favCandidates = data.nowList
        .where((c) => favorites.contains(c.id))
        .toList();
    favCandidates.sort((a, b) {
      final aRich = (data.nowByItemId[a.id]?.description?.isNotEmpty ?? false)
          ? 0
          : 1;
      final bRich = (data.nowByItemId[b.id]?.description?.isNotEmpty ?? false)
          ? 0
          : 1;
      return aRich.compareTo(bRich);
    });
    if (favCandidates.isNotEmpty) pick = favCandidates.first;

    // 2. Top history channel + live
    if (pick == null && history.isNotEmpty) {
      final freq = <String, int>{};
      for (final h in history) {
        freq.update(h.contentId, (v) => v + 1, ifAbsent: () => 1);
      }
      final ranked = freq.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in ranked) {
        // The history contentId may not be in nowList; iterate null-safe
        // instead of dropping firstWhere's orElse to a sentinel.
        for (final c in data.nowList) {
          if (c.id != entry.key) continue;
          if (data.nowByItemId.containsKey(c.id)) {
            pick = c;
            break;
          }
        }
        if (pick != null) break;
      }
    }

    // 3. TR popular allowlist → if none found, take the first of nowList.
    // If nowList is also empty we don't set a hero (the program-null
    // check below catches this).
    if (pick == null) {
      for (final c in data.nowList) {
        if (_isLikelyTrPopular(c)) {
          pick = c;
          break;
        }
      }
      pick ??= data.nowList.isNotEmpty ? data.nowList.first : null;
    }

    if (pick == null) {
      _heroChannel = null;
      _heroProgram = null;
      _heroLocked = false;
      return;
    }

    final program = data.nowByItemId[pick.id];
    if (program == null) {
      // Don't set a hero when nothing is live.
      _heroChannel = null;
      _heroProgram = null;
      _heroLocked = false;
      return;
    }
    _heroChannel = pick;
    _heroProgram = program;
    _heroLocked = true;
  }
}

/// Single-scan results for the Discover screen. Not re-filtered inside
/// build - only the itemBuilders iterate.
class _DiscoverData {
  final Map<String, EpgProgram> nowByItemId;
  final Map<String, EpgProgram> nextByItemId;
  final List<MediaItem> nowList;
  final List<MediaItem> soonList;
  final List<MediaItem> favoritesNow;
  final List<MediaItem> recentList;
  final List<MediaItem> mostWatchedList;
  final List<MediaItem> forYou;
  final List<MediaItem> eveningList;
  final List<MediaItem> newlyAddedList;
  final List<MediaItem> sportNow;
  final List<MediaItem> newsNow;
  final List<MediaItem> docsNow;
  final List<MediaItem> kidsNow;
  final List<MediaItem> musicNow;

  /// The "Evening" programs come from `nextProgram` windows; the main
  /// nextByItemId exceeds the 60-minute (Soon) limit, so we keep a
  /// separate map.
  final Map<String, EpgProgram> eveningProgramByItemId;
  _DiscoverData({
    required this.nowByItemId,
    required this.nextByItemId,
    required this.nowList,
    required this.soonList,
    required this.favoritesNow,
    required this.recentList,
    required this.mostWatchedList,
    required this.forYou,
    required this.eveningList,
    required this.newlyAddedList,
    required this.sportNow,
    required this.newsNow,
    required this.docsNow,
    required this.kidsNow,
    required this.musicNow,
    required this.eveningProgramByItemId,
  });
}

enum _CardVariant { now, soon, favorite }

/// The M3U `group-title` is mostly mixed text like "TR Spor", "USA
/// Movies". Reduce known genre words to a token.
Set<String> _categoryTokens(String? name) {
  if (name == null) return const <String>{};
  final low = name.toLowerCase();
  final out = <String>{};
  if (low.contains('spor') || low.contains('sport')) out.add('spor');
  if (low.contains('haber') || low.contains('news')) out.add('haber');
  if (low.contains('film') || low.contains('movie') || low.contains('cinema')) {
    out.add('film');
  }
  if (low.contains('belgesel') || low.contains('document')) out.add('belgesel');
  if (low.contains('çocuk') ||
      low.contains('cocuk') ||
      low.contains('kids') ||
      low.contains('cartoon')) {
    out.add('cocuk');
  }
  if (low.contains('müzik') || low.contains('muzik') || low.contains('music')) {
    out.add('muzik');
  }
  if (low.contains('dizi') || low.contains('series') || low.contains('drama')) {
    out.add('dizi');
  }
  return out;
}

/// Reference time for the "Evening" row - today at 19:00. If it is
/// already past 19:00 the window starts now (the evening isn't over yet);
/// after midnight it jumps to TOMORROW's 19:00.
DateTime _eveningStart(DateTime now) {
  if (now.hour >= 19) {
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }
  if (now.hour < 5) {
    // Night (00:00-05:00) - the "evening" is over, show tomorrow's.
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19, 0);
  }
  return DateTime(now.year, now.month, now.day, 19, 0);
}

bool _isLikelyTrPopular(MediaItem c) {
  final low = c.name.toLowerCase();
  const allowlist = [
    'trt 1',
    'trt1',
    'atv',
    'show tv',
    'star tv',
    'fox',
    'kanal d',
    'tv8',
    'ntv',
    'cnn türk',
    'cnnturk',
    'beyaz tv',
    'now tv',
  ];
  for (final n in allowlist) {
    if (low.contains(n)) return true;
  }
  final cat = c.categoryName?.toLowerCase() ?? '';
  return cat.contains('tr ') ||
      cat.startsWith('tr') ||
      cat.contains('türk') ||
      cat.contains('turk');
}

/// Thematic fill color by genre token - keeps cards from looking
/// monotonous when there is no backdrop data.
Color _paletteForCategory(String? name) {
  final tokens = _categoryTokens(name);
  if (tokens.contains('spor')) return const Color(0xFF1F4A3F);
  if (tokens.contains('haber')) return const Color(0xFF1F344A);
  if (tokens.contains('film')) return const Color(0xFF3D2A4A);
  if (tokens.contains('belgesel')) return const Color(0xFF3D331F);
  if (tokens.contains('cocuk')) return const Color(0xFF4A2A38);
  if (tokens.contains('muzik')) return const Color(0xFF3F1F4A);
  if (tokens.contains('dizi')) return const Color(0xFF2A2A4A);
  return AppColors.surfaceElevated;
}

class _HeroSpotlight extends ConsumerWidget {
  final MediaItem channel;
  final EpgProgram program;
  final DateTime now;
  final VoidCallback onPlay;
  const _HeroSpotlight({
    required this.channel,
    required this.program,
    required this.now,
    required this.onPlay,
  });

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  String _remaining(WidgetRef ref) {
    final remain = program.stop.difference(now);
    if (remain.inMinutes <= 0) return '';
    if (remain.inHours >= 1) {
      final h = remain.inHours;
      final m = remain.inMinutes % 60;
      return ref.tr('live.remainingHm', {'h': '$h', 'm': '$m'});
    }
    return ref.tr('live.remainingM', {'m': '${remain.inMinutes}'});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cleanTitle = program.title.replaceAll(RegExp(r'\s+'), ' ').trim();
    final cleanDesc = (program.description ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final palette = _paletteForCategory(channel.categoryName);
    final progress = program.progressAt(now);
    // On phones the hero is taller (so content fits and the title isn't
    // clipped) with a smaller title font. Wide screens keep the design.
    final isWide = MediaQuery.of(context).size.width >= 720;
    final heroHeight = isWide ? _kHeroHeight : 380.0;
    final titleFontSize = isWide ? 32.0 : 24.0;
    final titleMaxLines = isWide ? 2 : 3;

    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 16, isWide ? 24 : 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: heroHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background: category palette + large blurred logo silhouette.
              Container(color: palette),
              if (channel.logoUrl != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.18,
                    child: CachedNetworkImage(
                      imageUrl: channel.logoUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      placeholder: (_, _) =>
                          Container(color: Colors.transparent),
                      errorWidget: (_, _, _) =>
                          Container(color: Colors.transparent),
                    ),
                  ),
                ),
              // Gradient overlay - contrast for the text on the left.
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.background.withValues(alpha: 0.92),
                      AppColors.background.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ref.tr('live.badge'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  channel.displayName.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            cleanTitle,
                            maxLines: titleMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          if (cleanDesc.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              cleanDesc,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: onPlay,
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 22,
                                ),
                                label: Text(
                                  MediaQuery.of(context).size.width > 900
                                      ? ref.tr('live.watchNow')
                                      : ref.tr('live.watchShort'),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 12,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_hm(program.start)} – ${_hm(program.stop)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _remaining(ref),
                                style: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: SizedBox(
                              // Fixed 320 on wide screens, as wide as the
                              // text column on phones (so it doesn't overflow).
                              width: isWide ? 320 : double.infinity,
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 3,
                                backgroundColor: AppColors.surfaceElevated
                                    .withValues(alpha: 0.6),
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Right logo ONLY on wide screens. Hidden on phones so the
                    // text (badge + title) gets full width and isn't clipped.
                    // The background already has the blurred logo silhouette.
                    if (isWide && channel.logoUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: CachedNetworkImage(
                            imageUrl: channel.logoUrl!,
                            fit: BoxFit.contain,
                            placeholder: (_, _) => const SizedBox.shrink(),
                            errorWidget: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single horizontal row: title + ListView.builder of _LiveProgramCard.
class _Row extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final _CardVariant variant;
  final DateTime now;
  final Map<String, EpgProgram> nowMap;
  final Map<String, EpgProgram> nextMap;
  final void Function(MediaItem) onTap;

  const _Row({
    required this.title,
    required this.items,
    required this.variant,
    required this.now,
    required this.nowMap,
    required this.nextMap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _kCardHeight + 16,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              clipBehavior: Clip.none,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final c = items[i];
                final program = variant == _CardVariant.soon
                    ? nextMap[c.id]
                    : nowMap[c.id];
                if (program == null) {
                  return const SizedBox.shrink();
                }
                return _LiveProgramCard(
                  channel: c,
                  program: program,
                  variant: variant,
                  now: now,
                  onTap: () => onTap(c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveProgramCard extends StatefulWidget {
  final MediaItem channel;
  final EpgProgram program;
  final _CardVariant variant;
  final DateTime now;
  final VoidCallback onTap;
  const _LiveProgramCard({
    required this.channel,
    required this.program,
    required this.variant,
    required this.now,
    required this.onTap,
  });

  @override
  State<_LiveProgramCard> createState() => _LiveProgramCardState();
}

class _LiveProgramCardState extends State<_LiveProgramCard> {
  bool _hover = false;

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForCategory(widget.channel.categoryName);
    final cleanTitle = widget.program.title
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final isLive =
        widget.variant != _CardVariant.soon &&
        widget.program.isLiveAt(widget.now);
    final progress = isLive ? widget.program.progressAt(widget.now) : 0.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: _kCardWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              // Border color DOESN'T change on hover - user request.
              // We differentiate only with scale and a light shadow.
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Thematic background + blurred logo silhouette.
                  Container(color: palette),
                  if (widget.channel.logoUrl != null)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.16,
                        child: CachedNetworkImage(
                          imageUrl: widget.channel.logoUrl!,
                          fit: BoxFit.cover,
                          alignment: Alignment.centerRight,
                          placeholder: (_, _) => const SizedBox.shrink(),
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.background.withValues(alpha: 0.88),
                          AppColors.background.withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  // Channel logo in the top-left (small 28x28).
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: widget.channel.logoUrl == null
                          ? const Icon(
                              Icons.tv_rounded,
                              size: 16,
                              color: AppColors.textTertiary,
                            )
                          : CachedNetworkImage(
                              imageUrl: widget.channel.logoUrl!,
                              fit: BoxFit.contain,
                              placeholder: (_, _) => const SizedBox.shrink(),
                              errorWidget: (_, _, _) => const Icon(
                                Icons.tv_rounded,
                                size: 16,
                                color: AppColors.textTertiary,
                              ),
                            ),
                    ),
                  ),
                  // Badge in the top-right.
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _Badge(
                      variant: widget.variant,
                      program: widget.program,
                    ),
                  ),
                  // Bottom content: channel name, program name, time + progress.
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.channel.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cleanTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_hm(widget.program.start)} – ${_hm(widget.program.stop)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (isLive) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(1.5),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 2,
                              backgroundColor: AppColors.surfaceElevated
                                  .withValues(alpha: 0.6),
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends ConsumerWidget {
  final _CardVariant variant;
  final EpgProgram program;
  const _Badge({required this.variant, required this.program});

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (variant == _CardVariant.soon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          ref.tr('live.startingAtUpper', {'time': _hm(program.start)}),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      );
    }
    if (variant == _CardVariant.favorite) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
            const SizedBox(width: 4),
            Text(
              ref.tr('live.badge'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }
    // now (default live)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulseDot(),
          const SizedBox(width: 5),
          Text(
            ref.tr('live.badge'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value;
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.5 + t * 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.4 * t),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoEpgState extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.satellite_alt_rounded,
              size: 56,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 14),
            Text(
              ref.tr('live.discoverNoEpgTitle'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ref.tr('live.discoverNoEpgMsg'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyEpgPrograms extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.nightlight_round,
              size: 56,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 14),
            Text(
              ref.tr('live.discoverNoLiveTitle'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ref.tr('live.discoverNoLiveMsg'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// For `math.Random` global init (unused-import guard for the linter)
// ignore: unused_element
final _kRng = math.Random();
