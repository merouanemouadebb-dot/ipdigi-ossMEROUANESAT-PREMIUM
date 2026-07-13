import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
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

const double _kHeroHeight = 200;
const Duration _kAutoRotate = Duration(seconds: 6);
const int _kMaxCards = 8;

/// Horizontal auto-scrolling hero carousel that sits at the top of the
/// channels tab. Picks the currently-live ones from favorite + history
/// + popular channels. Scrolls page by page with a PageView; pauses the
/// auto loop if the user swipes manually - for predictability of the
/// interaction.
class LiveHeroCarousel extends ConsumerStatefulWidget {
  final List<MediaItem> liveChannels;
  const LiveHeroCarousel({super.key, required this.liveChannels});

  @override
  ConsumerState<LiveHeroCarousel> createState() => _LiveHeroCarouselState();
}

class _LiveHeroCarouselState extends ConsumerState<LiveHeroCarousel> {
  final _ctrl = PageController(viewportFraction: 0.92);
  Timer? _rotator;
  int _index = 0;
  bool _userInteracted = false;
  DateTime _now = DateTime.now();
  Timer? _minuteTicker;

  // Memoize: as long as the channel list + EPG snapshot reference stay
  // the same, the sorting is not redone.
  List<_HeroCandidate>? _cache;
  EpgSnapshot? _cacheEpg;
  List<MediaItem>? _cacheItems;
  Set<String>? _cacheFavs;
  int? _cacheNowMinute;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    Future.delayed(Duration(seconds: 60 - n.second), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _minuteTicker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _rotator?.cancel();
    _minuteTicker?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _ensureRotator(int total) {
    _rotator?.cancel();
    if (total <= 1 || _userInteracted) return;
    _rotator = Timer.periodic(_kAutoRotate, (_) {
      if (!mounted || !_ctrl.hasClients) return;
      final next = (_index + 1) % total;
      _ctrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<_HeroCandidate> _selectCandidates(
    EpgSnapshot snap,
    Set<String> favorites,
    List<HistoryEntry> history,
  ) {
    final epgIdent = identityHashCode(snap);
    final itemsIdent = identityHashCode(widget.liveChannels);
    final favIdent = identityHashCode(favorites);
    final nowMin = _now.millisecondsSinceEpoch ~/ 60000;
    if (_cache != null &&
        identityHashCode(_cacheEpg) == epgIdent &&
        identityHashCode(_cacheItems) == itemsIdent &&
        identityHashCode(_cacheFavs) == favIdent &&
        _cacheNowMinute == nowMin) {
      return _cache!;
    }

    final historyFreq = <String, int>{};
    for (final h in history) {
      historyFreq.update(h.contentId, (v) => v + 1, ifAbsent: () => 1);
    }

    // Collect all live channels.
    final all = <_HeroCandidate>[];
    final seen = <String>{};
    for (final c in widget.liveChannels) {
      if (isAdult(c)) continue;
      final cid = c.epgChannelId ?? c.streamId;
      var hit = snap.nowPlaying(c.sourceId, cid, _now);
      if (hit == null && c.epgChannelId != null) {
        hit = snap.nowPlaying(c.sourceId, c.streamId, _now);
      }
      if (hit == null) continue;
      // Skip programs with weak metadata - they look bad in a hero card.
      if (hit.title.trim().isEmpty) continue;
      seen.add(c.id);
      all.add(_HeroCandidate(channel: c, program: hit));
    }
    if (all.isEmpty) {
      _cache = const [];
    } else {
      // Score: favorite 100, history * 5, popular TR 10. Highest → first.
      int score(MediaItem c) {
        var s = 0;
        if (favorites.contains(c.id)) s += 100;
        s += (historyFreq[c.id] ?? 0) * 5;
        if (_isPopular(c)) s += 10;
        // A program with a description ranks a bit higher.
        return s;
      }

      all.sort((a, b) {
        final sa =
            score(a.channel) +
            ((a.program.description?.isNotEmpty ?? false) ? 3 : 0);
        final sb =
            score(b.channel) +
            ((b.program.description?.isNotEmpty ?? false) ? 3 : 0);
        return sb.compareTo(sa);
      });
      _cache = all.take(_kMaxCards).toList();
    }

    _cacheEpg = snap;
    _cacheItems = widget.liveChannels;
    _cacheFavs = favorites;
    _cacheNowMinute = nowMin;
    return _cache!;
  }

  bool _isPopular(MediaItem c) {
    final low = c.name.toLowerCase();
    const allow = [
      'trt 1',
      'trt1',
      'atv',
      'show tv',
      'star tv',
      'fox',
      'kanal d',
      'tv8',
      'ntv',
      'beyaz tv',
      'now tv',
    ];
    return allow.any(low.contains);
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(epgProvider).value;
    final favs = ref.watch(favoritesProvider).value ?? const <String>{};
    final history = ref.watch(historyProvider).value ?? const <HistoryEntry>[];

    if (snap == null || snap.bySource.isEmpty) {
      return const SizedBox.shrink();
    }
    final list = _selectCandidates(snap, favs, history);
    if (list.isEmpty) return const SizedBox.shrink();

    _ensureRotator(list.length);

    return SizedBox(
      height: _kHeroHeight,
      child: Column(
        children: [
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is UserScrollNotification &&
                    n.direction != ScrollDirection.idle) {
                  if (!_userInteracted) {
                    _userInteracted = true;
                    _rotator?.cancel();
                  }
                }
                return false;
              },
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: list.length,
                itemBuilder: (_, i) => _HeroCard(
                  candidate: list[i],
                  now: _now,
                  onPlay: () => _openChannel(list[i].channel),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _Dots(count: list.length, index: _index),
        ],
      ),
    );
  }

  void _openChannel(MediaItem item) {
    GoRouter.of(context).pushOnce(
      '/player',
      extra: PlayerArgs(item: item, isLive: true, startAt: Duration.zero),
    );
  }
}

class _HeroCandidate {
  final MediaItem channel;
  final EpgProgram program;
  const _HeroCandidate({required this.channel, required this.program});
}

class _HeroCard extends ConsumerWidget {
  final _HeroCandidate candidate;
  final DateTime now;
  final VoidCallback onPlay;
  const _HeroCard({
    required this.candidate,
    required this.now,
    required this.onPlay,
  });

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  Color _palette(String? name) {
    if (name == null) return AppColors.surfaceElevated;
    final low = name.toLowerCase();
    if (low.contains('spor') || low.contains('sport'))
      return const Color(0xFF1F4A3F);
    if (low.contains('haber') || low.contains('news'))
      return const Color(0xFF1F344A);
    if (low.contains('film') ||
        low.contains('cinema') ||
        low.contains('movie')) {
      return const Color(0xFF3D2A4A);
    }
    if (low.contains('belgesel') || low.contains('document'))
      return const Color(0xFF3D331F);
    if (low.contains('çocuk') ||
        low.contains('cocuk') ||
        low.contains('kids') ||
        low.contains('cartoon'))
      return const Color(0xFF4A2A38);
    if (low.contains('müzik') ||
        low.contains('muzik') ||
        low.contains('music')) {
      return const Color(0xFF3F1F4A);
    }
    return AppColors.surfaceElevated;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = candidate.channel;
    final p = candidate.program;
    final title = p.title.replaceAll(RegExp(r'\s+'), ' ').trim();
    final desc = (p.description ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final palette = _palette(c.categoryName);
    final progress = p.progressAt(now);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: onPlay,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: palette),
              if (c.logoUrl != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.16,
                    child: CachedNetworkImage(
                      imageUrl: c.logoUrl!,
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
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.background.withValues(alpha: 0.92),
                      AppColors.background.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
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
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  ref.tr('live.badge'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  c.displayName.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              height: 1.1,
                            ),
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: onPlay,
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 18,
                                ),
                                label: Text(ref.tr('common.watch')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${_hm(p.start)} – ${_hm(p.stop)}',
                                style: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: SizedBox(
                              width: 260,
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
                          ),
                        ],
                      ),
                    ),
                    if (c.logoUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: CachedNetworkImage(
                            imageUrl: c.logoUrl!,
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

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 4,
            decoration: BoxDecoration(
              color: i == index ? AppColors.accent : AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}
