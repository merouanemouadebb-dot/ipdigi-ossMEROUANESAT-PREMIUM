import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/nav_throttle.dart';
import '../../core/config/platform_info.dart';
import '../../core/l10n/i18n.dart';
import '../../core/metadata/tmdb_provider.dart';
import '../../core/metadata/tmdb_service.dart';
import '../../core/theme/app_theme.dart';
import '../sources/domain/media_item.dart';
import '../sources/providers/sources_provider.dart';

/// Actor profile, laid out like themoviedb.org: a left sidebar with the
/// portrait + personal info, a wide right column with bio, "Known For"
/// carousel, and a chronological "Acting" timeline. Catalog matches sit
/// just above Known For so the user can jump straight to what their own
/// library actually holds.
class PersonDetailPage extends ConsumerWidget {
  final String name;
  const PersonDetailPage({super.key, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personAsync = ref.watch(tmdbPersonProvider(name));
    final catalogAsync = ref.watch(
      libraryItemsProvider(const LibraryItemsArgs()),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: personAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(
          child: Text(
            '${ref.tr('common.error')}: $e',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        data: (person) {
          if (person == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  ref.tr('person.notFound'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }
          final catalog = catalogAsync.value ?? const <MediaItem>[];
          final catalogMatches = _matchCatalog(person.filmography, catalog);
          return LayoutBuilder(
            builder: (context, c) {
              // Tight layouts (narrow window, phone-ish) stack the sidebar
              // above the main content. Wide layouts use a true two-column
              // TMDB-style grid.
              if (c.maxWidth < 900) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Sidebar(person: person, compact: true),
                      const SizedBox(height: 18),
                      _MainColumn(
                        person: person,
                        catalogMatches: catalogMatches,
                      ),
                    ],
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 40),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 260,
                      child: _Sidebar(person: person, compact: false),
                    ),
                    const SizedBox(width: 36),
                    Expanded(
                      child: _MainColumn(
                        person: person,
                        catalogMatches: catalogMatches,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Cross-reference TMDB titles with M3U/Xtream titles. Both sides are
  // noisy (year suffixes, language tags, "4K"), so we normalize before
  // comparing. Returns catalog `MediaItem`s, not TMDB credits, so the
  // result is tappable through to existing detail routes.
  List<MediaItem> _matchCatalog(
    List<TmdbPersonCredit> credits,
    List<MediaItem> catalog,
  ) {
    String norm(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)'), ' ')
        .replaceAll(RegExp(r'\b(19|20)\d{2}\b'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final wanted = credits.map((c) => norm(c.title)).toSet()
      ..removeWhere((s) => s.isEmpty);
    if (wanted.isEmpty) return const [];
    final out = <MediaItem>[];
    for (final item in catalog) {
      if (item.kind == MediaKind.live) continue;
      if (wanted.contains(norm(item.name))) out.add(item);
    }
    return out;
  }
}

class _Sidebar extends ConsumerWidget {
  final TmdbPerson person;
  final bool compact;
  const _Sidebar({required this.person, required this.compact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: person.profileUrl != null
                ? CachedNetworkImage(
                    imageUrl: person.profileUrl!,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 220),
                    placeholder: (_, __) => Container(color: AppColors.surface),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.surface,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.textTertiary,
                        size: 72,
                      ),
                    ),
                  )
                : Container(
                    color: AppColors.surface,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.textTertiary,
                      size: 72,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          ref.tr('person.personalInfo'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (person.knownForDepartment != null)
          _InfoEntry(
            label: ref.tr('person.knownFor'),
            value: person.knownForDepartment!,
          ),
        _InfoEntry(
          label: ref.tr('person.knownCredits'),
          value: '${person.filmography.length}',
        ),
        if (person.gender != 0)
          _InfoEntry(
            label: ref.tr('person.gender'),
            value: _genderLabel(person.gender, ref),
          ),
        if (person.birthday != null)
          _InfoEntry(
            label: ref.tr('person.birthDate'),
            value: _formatBirthLine(person, ref),
          ),
        if (person.deathday != null)
          _InfoEntry(
            label: ref.tr('person.deathDate'),
            value: person.deathday!,
          ),
        if (person.placeOfBirth != null)
          _InfoEntry(
            label: ref.tr('person.birthPlace'),
            value: person.placeOfBirth!,
          ),
        if (person.alsoKnownAs.isNotEmpty)
          _InfoEntry(
            label: ref.tr('person.alsoKnownAs'),
            value: person.alsoKnownAs.join('\n'),
          ),
      ],
    );
  }

  String _genderLabel(int gender, WidgetRef ref) {
    switch (gender) {
      case 1:
        return ref.tr('person.genderFemale');
      case 2:
        return ref.tr('person.genderMale');
      default:
        return ref.tr('person.genderOther');
    }
  }

  String _formatBirthLine(TmdbPerson p, WidgetRef ref) {
    final base = p.birthday ?? '';
    final age = p.age;
    if (age == null) return base;
    final ageText = ref.tr('person.ageYears', {'n': '$age'});
    return '$base ($ageText)';
  }
}

class _InfoEntry extends StatelessWidget {
  final String label;
  final String value;
  const _InfoEntry({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _MainColumn extends ConsumerWidget {
  final TmdbPerson person;
  final List<MediaItem> catalogMatches;
  const _MainColumn({required this.person, required this.catalogMatches});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final knownFor = person.filmography.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          person.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          ref.tr('person.biography'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _BioBlock(text: person.biography),
        if (catalogMatches.isNotEmpty) ...[
          const SizedBox(height: 28),
          _LibraryRow(items: catalogMatches),
        ],
        if (knownFor.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(
            ref.tr('person.knownFor'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: knownFor.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _KnownForCard(credit: knownFor[i]),
            ),
          ),
        ],
        const SizedBox(height: 28),
        Text(
          ref.tr('person.acting'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _ActingTimeline(credits: person.filmography, ref: ref),
      ],
    );
  }
}

class _BioBlock extends StatefulWidget {
  final String? text;
  const _BioBlock({required this.text});

  @override
  State<_BioBlock> createState() => _BioBlockState();
}

class _BioBlockState extends State<_BioBlock> {
  bool _expanded = false;
  // Collapsed cap. ~6 lines of body copy gives the "Read More" affordance
  // without making short bios look truncated.
  static const _collapsedMax = 6;

  @override
  Widget build(BuildContext context) {
    final t = widget.text?.trim() ?? '';
    if (t.isEmpty) {
      return Consumer(
        builder: (context, ref, _) {
          return Text(
            ref.tr('person.noBio'),
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          );
        },
      );
    }
    return Consumer(
      builder: (context, ref, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: Text(
                t,
                maxLines: _expanded ? null : _collapsedMax,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded
                          ? ref.tr('person.readLess')
                          : ref.tr('person.readMore'),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LibraryRow extends ConsumerWidget {
  final List<MediaItem> items;
  const _LibraryRow({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ref.tr('person.inYourLibrary'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final item = items[i];
              return _LibraryCard(
                item: item,
                onTap: () {
                  if (item.kind == MediaKind.movie) {
                    context.pushOnce(
                      '/movie/${item.sourceId}/${item.streamId}',
                    );
                  } else if (item.kind == MediaKind.series) {
                    context.pushOnce(
                      '/series/${item.sourceId}/${item.streamId}',
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LibraryCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const _LibraryCard({required this.item, required this.onTap});

  @override
  State<_LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<_LibraryCard> {
  bool _hover = false;
  bool _focus = false;
  bool get _active => _hover || _focus;

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        onFocusChange: (v) => setState(() => _focus = v),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _active ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 160),
            child: SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: (_focus && PlatformInfo.isTv)
                          ? Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.accent, width: 3),
                              ),
                              child: _libraryThumb(i),
                            )
                          : _libraryThumb(i),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    i.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

  Widget _libraryThumb(MediaItem i) {
    return i.logoUrl != null
        ? CachedNetworkImage(
            imageUrl: i.logoUrl!,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 220),
            placeholder: (_, __) => Container(color: AppColors.surface),
            errorWidget: (_, __, ___) => Container(color: AppColors.surface),
          )
        : Container(
            color: AppColors.surface,
            alignment: Alignment.center,
            child: Icon(
              i.kind == MediaKind.series
                  ? Icons.tv_rounded
                  : Icons.movie_rounded,
              color: AppColors.textTertiary,
              size: 32,
            ),
          );
  }
}

class _KnownForCard extends StatelessWidget {
  final TmdbPersonCredit credit;
  const _KnownForCard({required this.credit});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: credit.posterUrl != null
                  ? CachedNetworkImage(
                      imageUrl: credit.posterUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 220),
                      placeholder: (_, __) =>
                          Container(color: AppColors.surface),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppColors.surface),
                    )
                  : Container(
                      color: AppColors.surface,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.movie_rounded,
                        color: AppColors.textTertiary,
                        size: 32,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            credit.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActingTimeline extends StatelessWidget {
  final List<TmdbPersonCredit> credits;
  final WidgetRef ref;
  const _ActingTimeline({required this.credits, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (credits.isEmpty) {
      return const SizedBox.shrink();
    }
    final sorted = List<TmdbPersonCredit>.of(credits);
    // Newest first, mirroring the TMDB.org default ordering.
    sorted.sort((a, b) {
      final ay = _year(a.releaseDate);
      final by = _year(b.releaseDate);
      if (ay == null && by == null) return 0;
      if (ay == null) return 1;
      if (by == null) return -1;
      return by.compareTo(ay);
    });
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sorted.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, i) => _ActingRow(credit: sorted[i], ref: ref),
      ),
    );
  }

  static int? _year(String? raw) {
    if (raw == null || raw.length < 4) return null;
    return int.tryParse(raw.substring(0, 4));
  }
}

class _ActingRow extends StatelessWidget {
  final TmdbPersonCredit credit;
  final WidgetRef ref;
  const _ActingRow({required this.credit, required this.ref});

  @override
  Widget build(BuildContext context) {
    final year = _ActingTimeline._year(credit.releaseDate);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              year?.toString() ?? '-',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  credit.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (credit.character != null && credit.character!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      ref.tr('person.asCharacter', {
                        'character': credit.character!,
                      }),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
