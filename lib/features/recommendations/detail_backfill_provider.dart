import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sources/domain/media_item.dart';
import '../sources/providers/sources_provider.dart';
import 'related_provider.dart';

/// State is a monotonic version counter - bumped every [_batchSize] details
/// fetched so widgets watching this provider re-render and re-query the
/// index. The full TF-IDF rebuild is avoided: the index is updated in
/// place via [RelatedService.addDetail].
class DetailBackfillController extends Notifier<int> {
  static const _batchSize = 12;
  static const _gap = Duration(milliseconds: 250);
  bool _running = false;

  @override
  int build() => 0;

  Future<void> trigger() async {
    if (_running) return;
    _running = true;
    try {
      final repo = ref.read(sourceRepositoryProvider);
      final all = await ref.read(
        libraryItemsProvider(const LibraryItemsArgs()).future,
      );
      final existing = await repo.allDetailsById();
      final sources = await ref.read(sourcesProvider.future);
      final sourceById = {for (final s in sources) s.id: s};

      final missing = all
          .where(
            (i) => i.kind == MediaKind.movie && !existing.containsKey(i.id),
          )
          .toList();

      final service = ref.read(relatedServiceProvider);
      var fetched = 0;
      for (final item in missing) {
        final src = sourceById[item.sourceId];
        if (src == null) continue;
        try {
          final d = await repo.movieDetail(src, item);
          if (d != null) {
            await repo.putDetail(item, d);
            if (service.isReady) service.addDetail(item, d);
            fetched++;
          }
        } catch (_) {}
        if (fetched > 0 && fetched % _batchSize == 0) {
          state = state + 1;
          // Refresh the shared map as new details are written - the home /
          // continue row poster and cast info fill in gradually.
          ref.invalidate(cachedDetailsMapProvider);
          await Future.delayed(_gap);
        }
      }
      if (fetched > 0) {
        state = state + 1;
        ref.invalidate(cachedDetailsMapProvider);
      }
    } finally {
      _running = false;
    }
  }
}

final detailBackfillProvider = NotifierProvider<DetailBackfillController, int>(
  DetailBackfillController.new,
);
