import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_info_provider.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../sources/domain/source.dart';
import '../../sources/providers/sources_provider.dart';
import '../domain/xtream_account_info.dart';
import '../providers/profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  // Flag that turns the button into a spinner during refresh and blocks
  // repeat taps. Previous behavior: only `profileEntriesProvider` was
  // invalidated - since the Xtream account info pull rarely changes, the
  // user would say "nothing happened". Now it does a real catalog
  // refresh (refreshAll), and the last-updated times change
  // too.
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      // Re-download all sources - so cached_channels MAX(cached_at) gets
      // triggered. refreshAll does per-source try/catch internally; if
      // one source fails the others continue.
      await ref.read(sourcesProvider.notifier).refreshAll();
      // Refresh the Xtream account info as well.
      ref.invalidate(profileEntriesProvider);
      // Per-source last-updated time is a provider family - we can't
      // invalidate them all at once since it's arg-based; but inside
      // refreshAll each sourceLastUpdatedProvider(id) is already
      // invalidated (sources_provider.dart:80).
      if (mounted && messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(ref.tr('profile.refreshed')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted && messenger != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('${ref.tr('common.error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(profileEntriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('profile.title')),
        actions: [
          IconButton(
            tooltip: ref.tr('profile.refresh'),
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _refreshing ? null : _refresh,
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(
          child: Text(
            '${ref.tr('common.error')}: $e',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        data: (entries) {
          // At the top a version band + Account block (Apple/Google
          // sign-in, sign-out, account deletion). The account block is
          // shown independently of sources - so the user can sign in even
          // with no sources. Source cards below.
          if (entries.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                const _AppInfoBanner(),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    ref.tr('profile.noSources'),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            itemCount: entries.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, i) {
              if (i == 0) return const _AppInfoBanner();
              return _ProfileCard(entry: entries[i - 1]);
            },
          );
        },
      ),
    );
  }
}

/// Version + build number band at the top of the profile page. A more
/// prominent / detailed version of the faint label in the sidebar.
class _AppInfoBanner extends ConsumerWidget {
  const _AppInfoBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(appInfoProvider);
    return infoAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (info) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${info.appName} ${info.version}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Build ${info.buildNumber}',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  final ProfileEntry entry;
  const _ProfileCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = entry.info;
    final src = entry.source;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accent.withValues(alpha: 0.14),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      src.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _sourceKindLabel(src),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (info != null) _StatusChip(info: info, ref: ref),
            ],
          ),
          const SizedBox(height: 18),
          if (info != null)
            _InfoGrid(info: info)
          else if (entry.error != null)
            Text(
              '${ref.tr('profile.loadError')}: ${entry.error}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            )
          else
            Text(
              ref.tr('profile.noXtream'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          // The source's last cache refresh time at the bottom of the
          // card. MAX of the cached_at column - represents "the last
          // successful sync". Null means never loaded; the row is hidden.
          const SizedBox(height: 14),
          _LastUpdatedLine(sourceId: src.id),
        ],
      ),
    );
  }

  String _sourceKindLabel(IptvSource s) {
    switch (s.kind) {
      case SourceKind.xtream:
        return 'Xtream';
      case SourceKind.m3u:
        return 'M3U';
      case SourceKind.direct:
        return 'URL';
    }
  }
}

/// The "Last updated: X min ago" line at the bottom of the card. The
/// data comes from `sourceLastUpdatedProvider` (cached_channels.cached_at
/// MAX). The row is hidden for sources that were never loaded.
class _LastUpdatedLine extends ConsumerWidget {
  final String sourceId;
  const _LastUpdatedLine({required this.sourceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sourceLastUpdatedProvider(sourceId));
    final at = async.value;
    if (at == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(
          Icons.cloud_done_outlined,
          size: 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 6),
        Text(
          '${ref.tr('profile.lastUpdated')}: ${_relativeTime(at, ref)}',
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Simple relative time: "just now / X min ago / X h ago / yesterday /
  /// X days ago / full date". The i18n keys live under profile.*.
  String _relativeTime(DateTime at, WidgetRef ref) {
    final now = DateTime.now();
    final diff = now.difference(at);
    if (diff.inSeconds < 45) return ref.tr('profile.justNow');
    if (diff.inMinutes < 60) {
      return ref.tr('profile.minutesAgo', {'n': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return ref.tr('profile.hoursAgo', {'n': '${diff.inHours}'});
    }
    if (diff.inDays == 1) return ref.tr('profile.yesterday');
    if (diff.inDays < 7) {
      return ref.tr('profile.daysAgo', {'n': '${diff.inDays}'});
    }
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}';
  }
}

class _StatusChip extends StatelessWidget {
  final XtreamAccountInfo info;
  final WidgetRef ref;
  const _StatusChip({required this.info, required this.ref});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    final status = info.status?.toLowerCase() ?? '';
    if (info.isExpired || status == 'expired') {
      label = ref.tr('profile.expired');
      color = const Color(0xFFE57373);
    } else if (status == 'banned' || status == 'disabled') {
      label = ref.tr('profile.banned');
      color = const Color(0xFFE57373);
    } else if (info.isTrial) {
      label = ref.tr('profile.trial');
      color = const Color(0xFFFFB74D);
    } else if (status == 'active' || status.isEmpty) {
      label = ref.tr('profile.active');
      color = const Color(0xFF66BB6A);
    } else {
      label = info.status ?? '';
      color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _InfoGrid extends ConsumerWidget {
  final XtreamAccountInfo info;
  const _InfoGrid({required this.info});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = <List<Widget>>[];
    if (info.username != null && info.username!.isNotEmpty) {
      rows.add([_label(ref.tr('profile.username')), _value(info.username!)]);
    }
    rows.add([_label(ref.tr('profile.expiry')), _value(_expiryText(ref))]);
    if (info.maxConnections != null || info.activeConnections != null) {
      rows.add([
        _label(ref.tr('profile.connections')),
        _value(
          ref.tr('profile.connectionsValue', {
            'active': '${info.activeConnections ?? 0}',
            'max': '${info.maxConnections ?? 0}',
          }),
        ),
      ]);
    }
    if (info.allowedFormats.isNotEmpty) {
      rows.add([
        _label(ref.tr('profile.formats')),
        _value(info.allowedFormats.join(', ')),
      ]);
    }
    if (info.serverUrl != null && info.serverUrl!.isNotEmpty) {
      rows.add([_label(ref.tr('profile.server')), _value(info.serverUrl!)]);
    }
    if (info.timezone != null && info.timezone!.isNotEmpty) {
      rows.add([_label(ref.tr('profile.timezone')), _value(info.timezone!)]);
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 22, color: AppColors.divider),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 150, child: rows[i][0]),
              Expanded(child: rows[i][1]),
            ],
          ),
        ],
      ],
    );
  }

  String _expiryText(WidgetRef ref) {
    final e = info.expiresAt;
    if (e == null) return ref.tr('profile.noExpiry');
    final two = (int n) => n.toString().padLeft(2, '0');
    final date = '${e.year}-${two(e.month)}-${two(e.day)}';
    if (info.isExpired) {
      return '$date · ${ref.tr('profile.expiredAlready')}';
    }
    final days = info.daysLeft ?? 0;
    final left = ref.tr('profile.daysLeft', {'days': '$days'});
    return '$date · $left';
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textTertiary,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );

  Widget _value(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
  );
}
