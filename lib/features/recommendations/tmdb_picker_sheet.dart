import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/i18n.dart';
import '../../core/widgets/dpad_text_field.dart';
import '../../core/metadata/tmdb_overrides_provider.dart';
import '../../core/metadata/tmdb_provider.dart';
import '../../core/metadata/tmdb_service.dart';
import '../../core/theme/app_theme.dart';
import '../series/providers/series_detail_provider.dart' as series_prov;
import '../sources/data/source_repository.dart';
import '../sources/domain/media_item.dart';
import '../sources/providers/sources_provider.dart';
import '../vod/providers/movie_detail_provider.dart';
import 'personalized_recommender.dart';
import 'related_provider.dart';

/// The "Wrong movie?" sheet. The user opens it from the detail page and
/// searches freely via TMDB; picking a result saves an override for that
/// composite item-id, [tmdbDetailProvider] is invalidated, and the card
/// refreshes.
class TmdbPickerSheet extends ConsumerStatefulWidget {
  final String sourceId;
  final String contentId;
  final String initialQuery;
  /// Whether the item is a movie or a series - only to surface that type
  /// higher in the ordering; the search is still multi-search.
  final bool isMovie;
  const TmdbPickerSheet({
    super.key,
    required this.sourceId,
    required this.contentId,
    required this.initialQuery,
    required this.isMovie,
  });

  static Future<void> show(
    BuildContext context, {
    required String sourceId,
    required String contentId,
    required String initialQuery,
    required bool isMovie,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TmdbPickerSheet(
        sourceId: sourceId,
        contentId: contentId,
        initialQuery: initialQuery,
        isMovie: isMovie,
      ),
    );
  }

  @override
  ConsumerState<TmdbPickerSheet> createState() => _TmdbPickerSheetState();
}

class _TmdbPickerSheetState extends ConsumerState<TmdbPickerSheet> {
  late final TextEditingController _ctl;
  Timer? _debounce;
  List<TmdbSearchHit> _hits = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // The panel name may carry scene-release residue (like "Concussion
    // (2013) 1080p BluRay") - cleanTitle strips the parenthesized year and
    // the tags to send a clean query to TMDB. The user can edit it in the
    // box if they want.
    final cleaned = cleanTitle(widget.initialQuery);
    _ctl = TextEditingController(
      text: cleaned.isNotEmpty ? cleaned : widget.initialQuery,
    );
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _search(_ctl.text));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(value);
    });
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _hits = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final svc = ref.read(tmdbServiceProvider);
    final locale = ref.read(localeProvider).value?.code ?? 'en';
    final lang = _tmdbLang(locale);
    final hits = await svc.searchMulti(
      query: q,
      language: lang,
      limit: 20,
    );
    if (!mounted) return;
    // Surface the item type first - if the user opened this from a movie
    // detail, put movies on top.
    final sorted = [...hits]..sort((a, b) {
        final aMatch = a.isMovie == widget.isMovie ? 0 : 1;
        final bMatch = b.isMovie == widget.isMovie ? 0 : 1;
        if (aMatch != bMatch) return aMatch - bMatch;
        // Within the same type, popularity/relevance ordering already comes
        // from TMDB's default order.
        return 0;
      });
    setState(() {
      _hits = sorted;
      _loading = false;
    });
  }

  String _tmdbLang(String locale) {
    if (locale.startsWith('tr')) return 'tr-TR';
    if (locale.contains('-')) return locale;
    return '$locale-${locale.toUpperCase()}';
  }

  Future<void> _pick(TmdbSearchHit hit) async {
    final id = hit.tmdbId;
    if (id == null) return;
    await ref.read(tmdbOverridesProvider.notifier).save(
          contentId: widget.contentId,
          sourceId: widget.sourceId,
          tmdbId: id,
          isMovie: hit.isMovie,
        );
    // Fill cached_details immediately with the new TMDB data. Otherwise
    // home / continue row / lists keep showing the old panel logoUrls until
    // the next cold start. The detail fetch is for a single item only, so
    // the extra cost is negligible.
    await _refreshCachedDetail(
      tmdbId: id,
      isMovie: hit.isMovie,
    );
    await _propagateOverrideChange();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clearOverride() async {
    await ref.read(tmdbOverridesProvider.notifier).remove(
          contentId: widget.contentId,
          sourceId: widget.sourceId,
        );
    // On reset the cached_details row must be deleted: if the previous
    // override data stays there, the detail page keeps showing the old TMDB
    // cast even though the override was cleared. On the next open,
    // movieDetailProvider re-fetches with the default algorithm.
    final repo = ref.read(sourceRepositoryProvider);
    await repo.deleteDetail(widget.contentId);
    await _propagateOverrideChange();
    if (mounted) Navigator.of(context).pop();
  }

  /// Fetch the detail with the TMDB id picked in the picker and write the
  /// cached_details row with the new metadata. If the fetch fails, pass
  /// silently - _propagateOverrideChange() will have deleted the row anyway;
  /// when the detail page opens, movieDetailProvider fills it via a re-fetch.
  Future<void> _refreshCachedDetail({
    required int tmdbId,
    required bool isMovie,
  }) async {
    final repo = ref.read(sourceRepositoryProvider);
    final svc = ref.read(tmdbServiceProvider);
    if (!svc.enabled) return;
    final item = await ref.read(mediaItemByIdProvider(widget.contentId).future);
    if (item == null) return;
    final locale = ref.read(localeProvider).value?.code ?? 'en';
    final language = _tmdbLang(locale);
    final region = locale.toUpperCase();
    try {
      final tmdb = isMovie
          ? await svc.fetchMovieById(tmdbId,
              language: language, region: region)
          : await svc.fetchTvById(tmdbId,
              language: language, region: region);
      if (tmdb == null) return;
      // preferTmdb: true - since the override is active, TMDB cast/plot
      // should always take the panel's place.
      final merged = mergeWithTmdb(
        const MediaDetail(),
        tmdb,
        preferTmdb: true,
      );
      await repo.putDetail(item, merged);
    } catch (_) {
      // Best-effort; deleteDetail will run afterwards anyway.
    }
  }

  /// Propagate the effect of the override change to the whole UI. After
  /// rewriting cached_details, here we ONLY invalidate the providers - once
  /// libraryItemsProvider refreshes, the home/continue row is redrawn with
  /// the new poster too.
  Future<void> _propagateOverrideChange() async {
    ref.invalidate(tmdbDetailProvider);
    ref.invalidate(movieDetailProvider);
    ref.invalidate(series_prov.seriesDetailProvider);
    ref.invalidate(relatedItemsProvider);
    ref.invalidate(personalizedRecommendationsProvider);
    ref.invalidate(libraryItemsProvider);
    // Refresh the shared cached_details map too - libraryItemsProvider
    // watches it; otherwise the stale cached poster URLs keep reflecting
    // into the home/continue row.
    ref.invalidate(cachedDetailsMapProvider);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final hasOverride = ref
            .watch(tmdbOverridesProvider)
            .value
            ?.containsKey(widget.contentId) ??
        false;
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: mq.size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  ref.tr('tmdbPicker.title'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  ref.tr('tmdbPicker.subtitle'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DpadTextField(
                  child: TextField(
                  controller: _ctl,
                  autofocus: true,
                  onChanged: _onChanged,
                  onSubmitted: _search,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: ref.tr('tmdbPicker.hint'),
                    hintStyle:
                        const TextStyle(color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textTertiary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accent),
                    ),
                  ),
                ),
                ),
              ),
              const SizedBox(height: 12),
              if (hasOverride)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        color: AppColors.accent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ref.tr('tmdbPicker.hasOverride'),
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _clearOverride,
                        child: Text(ref.tr('tmdbPicker.clearOverride')),
                      ),
                    ],
                  ),
                ),
              Flexible(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _hits.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Text(
                                ref.tr('tmdbPicker.noResults'),
                                style: const TextStyle(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            itemCount: _hits.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, i) {
                              final h = _hits[i];
                              return _HitTile(hit: h, onTap: () => _pick(h));
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  final TmdbSearchHit hit;
  final VoidCallback onTap;
  const _HitTile({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: hit.tmdbId == null ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 52,
                  height: 78,
                  child: hit.posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: hit.posterUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.surface),
                          errorWidget: (_, __, ___) => const _PosterFallback(),
                        )
                      : const _PosterFallback(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hit.title.isNotEmpty ? hit.title : hit.originalTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (hit.originalTitle.isNotEmpty &&
                        hit.originalTitle.toLowerCase() !=
                            hit.title.toLowerCase())
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          hit.originalTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            hit.isMovie ? 'FILM' : 'DİZİ',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (hit.year != null)
                          Text(
                            hit.year.toString(),
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        if (hit.rating != null && hit.rating! > 0) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            hit.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: const Icon(
        Icons.movie_outlined,
        color: AppColors.textTertiary,
      ),
    );
  }
}
