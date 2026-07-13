import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/domain/media_item.dart';
import '../../sources/providers/sources_provider.dart';

class InfoDetailArgs {
  final String sourceId;
  final String streamId;
  final MediaKind kind;
  const InfoDetailArgs({
    required this.sourceId,
    required this.streamId,
    required this.kind,
  });

  @override
  bool operator ==(Object other) =>
      other is InfoDetailArgs &&
      other.sourceId == sourceId &&
      other.streamId == streamId &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(sourceId, streamId, kind);
}

class InfoDetail {
  final MediaItem item;
  final MediaDetail? detail;
  const InfoDetail({required this.item, this.detail});
}

final infoDetailProvider = FutureProvider.autoDispose
    .family<InfoDetail?, InfoDetailArgs>((ref, args) async {
      final id = MediaItem.makeId(args.sourceId, args.streamId);
      final item = await ref.watch(mediaItemByIdProvider(id).future);
      if (item == null) return null;
      final src = await ref.watch(sourceByIdProvider(args.sourceId).future);
      if (src == null) return InfoDetail(item: item);
      final repo = ref.read(sourceRepositoryProvider);
      MediaDetail? detail;
      try {
        if (args.kind == MediaKind.movie) {
          detail = await repo.movieDetail(src, item);
        } else if (args.kind == MediaKind.series) {
          final sd = await repo.seriesDetail(src, item);
          detail = sd?.detail;
        }
      } catch (_) {}
      return InfoDetail(item: item, detail: detail);
    });
