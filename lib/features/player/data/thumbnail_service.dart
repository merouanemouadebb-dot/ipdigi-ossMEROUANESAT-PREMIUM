import 'dart:async';
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';

/// Hover scrub thumbnail provider. A hidden, paused, muted Player instance
/// pulls the same stream as the main player and exposes frame snapshots for
/// arbitrary positions via `seek + screenshot`.
///
/// Frames are cached by integer second; closest cached frame is returned for
/// in-flight requests so the bubble never goes blank once warm.
class ThumbnailService {
  final Player player;
  final Map<int, Uint8List> _cache = {};
  final Set<int> _failed = {};
  Timer? _debounce;
  bool _ready = false;
  bool _busy = false;
  int? _pendingRequest;

  ThumbnailService(this.player);

  Future<void> openSource(String url) async {
    try {
      await player.setVolume(0);
      await player.open(Media(url), play: false);
      await player.pause();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  bool get isReady => _ready;

  Uint8List? frameAtSecond(int seconds) {
    if (_cache.isEmpty) return null;
    if (_cache.containsKey(seconds)) return _cache[seconds];
    int? closest;
    int closestDiff = 1 << 30;
    for (final k in _cache.keys) {
      final d = (k - seconds).abs();
      if (d < closestDiff) {
        closestDiff = d;
        closest = k;
      }
    }
    return closest == null ? null : _cache[closest];
  }

  /// Schedules a capture for [seconds]. Coalesces fast-moving hover requests
  /// so we only seek/screenshot at most every ~180ms.
  void requestAt(int seconds) {
    if (!_ready) return;
    if (_cache.containsKey(seconds) || _failed.contains(seconds)) return;
    _pendingRequest = seconds;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), _drain);
  }

  Future<void> _drain() async {
    if (_busy) return;
    final target = _pendingRequest;
    if (target == null) return;
    _busy = true;
    try {
      await player.seek(Duration(seconds: target));
      await Future<void>.delayed(const Duration(milliseconds: 220));
      final bytes = await player.screenshot();
      if (bytes != null && bytes.isNotEmpty) {
        _cache[target] = bytes;
        if (_cache.length > 240) {
          _cache.remove(_cache.keys.first);
        }
      } else {
        _failed.add(target);
      }
    } catch (_) {
      _failed.add(target);
    } finally {
      _busy = false;
      if (_pendingRequest != target && _pendingRequest != null) {
        unawaited(_drain());
      }
    }
  }

  void dispose() {
    _debounce?.cancel();
    _cache.clear();
    _failed.clear();
  }
}
