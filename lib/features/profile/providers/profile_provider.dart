import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../sources/data/xtream_api.dart';
import '../../sources/domain/source.dart';
import '../../sources/providers/sources_provider.dart';
import '../domain/xtream_account_info.dart';

final _xtreamApiProvider = Provider<XtreamApi>((ref) {
  return XtreamApi(ref.watch(dioProvider));
});

class ProfileEntry {
  final IptvSource source;
  final XtreamAccountInfo? info;
  final Object? error;
  const ProfileEntry({required this.source, this.info, this.error});
}

/// Walks every saved [IptvSource]. Xtream sources fire a single auth
/// call to surface subscription state; other source kinds (M3U / direct
/// URL) return an entry with no info (the page renders a placeholder).
/// Failures don't crash the page - they're captured per-entry so one
/// dead server doesn't hide every profile.
final profileEntriesProvider = FutureProvider.autoDispose<List<ProfileEntry>>((
  ref,
) async {
  final sources = await ref.watch(sourcesProvider.future);
  final api = ref.watch(_xtreamApiProvider);
  final out = <ProfileEntry>[];
  for (final s in sources) {
    if (s is XtreamSource) {
      try {
        final info = await api.accountInfo(s);
        out.add(ProfileEntry(source: s, info: info));
      } catch (e) {
        out.add(ProfileEntry(source: s, error: e));
      }
    } else {
      out.add(ProfileEntry(source: s));
    }
  }
  return out;
});
