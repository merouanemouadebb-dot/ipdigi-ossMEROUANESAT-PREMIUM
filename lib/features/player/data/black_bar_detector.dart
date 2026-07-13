import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:media_kit/media_kit.dart';

/// Detected black bar edges, as a fraction of the frame size (0.0-1.0).
/// E.g. top=0.06 → the top 6% of the image is consistently black.
class BlackBarResult {
  final double top;
  final double bottom;
  final double left;
  final double right;
  final int frameWidth;
  final int frameHeight;
  final int samples;

  const BlackBarResult({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
    required this.frameWidth,
    required this.frameHeight,
    required this.samples,
  });

  /// The content's real width/height ratio (after black bars are removed).
  /// The main metric for computing the current zoom scale.
  double get contentAspectRatio {
    final w = frameWidth * (1.0 - left - right);
    final h = frameHeight * (1.0 - top - bottom);
    if (h <= 0) return 0;
    return w / h;
  }

  /// The container's aspect ratio (the full frame the codec reports).
  double get frameAspectRatio =>
      frameHeight == 0 ? 0 : frameWidth / frameHeight;

  /// Letterbox (top+bottom) vs pillarbox (side) dominance; used to decide
  /// which direction to zoom.
  double get verticalBars => top + bottom;
  double get horizontalBars => left + right;

  /// If all edges are practically zero, there is no meaningful bar.
  bool get hasBars =>
      top > 0.005 || bottom > 0.005 || left > 0.005 || right > 0.005;

  @override
  String toString() {
    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
    return 'BlackBar(top=${pct(top)}, bottom=${pct(bottom)}, '
        'left=${pct(left)}, right=${pct(right)}, '
        'frame=${frameWidth}x$frameHeight, '
        'contentAR=${contentAspectRatio.toStringAsFixed(3)}, '
        'samples=$samples)';
  }
}

/// Edge scan result for a single frame. Used when merging across frames -
/// each edge's "consistently black across all frames" part = min(top),
/// min(bottom)...
class _FrameEdges {
  final double top;
  final double bottom;
  final double left;
  final double right;
  final int width;
  final int height;
  const _FrameEdges(
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.width,
    this.height,
  );
}

class BlackBarDetector {
  /// 0-255 luminance threshold; pixels below this value count as "black".
  /// 24 is empirical: real hardcoded black bars are 0-8, but H.264/HEVC
  /// compression leaves 16-22 noise in the edge macroblocks. 24 folds that
  /// noise into black while separating it from the real image (usually 30+).
  final int luminanceThreshold;

  /// How much of a row/column must be black for us to accept it as a
  /// "black line". 0.97 = 97% → small logo / subtitle bands do not
  /// mislead it.
  final double rowBlackRatio;

  /// To lower the scan cost per frame: go inward from the edges at most
  /// this fraction (the rest is the image center, scanning is
  /// unnecessary). A typical letterbox rarely exceeds 20%.
  final double maxScanFraction;

  const BlackBarDetector({
    this.luminanceThreshold = 24,
    this.rowBlackRatio = 0.97,
    this.maxScanFraction = 0.35,
  });

  /// Takes N screenshots (default 10), scans the edges in each, and merges
  /// across frames with the **mode** (most frequent). Bucket width is 1%.
  ///
  /// Why mode, not min: with 5 samples min was fine (a real hardcoded bar
  /// is the same in every frame, a temporary dark scene does not spoil the
  /// min). But in practice there can be a dark object on the left of the
  /// content for 5 frames → false positive. With the mode, the most
  /// frequent bar size wins: a real hardcoded bar is always consistent
  /// (like 12.8%), while a temporary dark object differs per scene (0,
  /// 18%, 5%, 22%) - it scatters, and the mode stays at 0.
  ///
  /// [intervalMs] is how long to wait between samples. On live streams
  /// there is no seek; we just let time pass and capture a new frame. On
  /// VOD we also avoid seeking so we don't jolt the user - since playback
  /// already advances, each sample lands on a different frame.
  Future<BlackBarResult?> detect(
    Player player, {
    int samples = 10,
    int intervalMs = 600,
  }) async {
    final frames = <_FrameEdges>[];
    for (var i = 0; i < samples; i++) {
      if (i > 0) {
        await Future.delayed(Duration(milliseconds: intervalMs));
      }
      try {
        final bytes = await player.screenshot(format: 'image/jpeg');
        if (bytes == null || bytes.isEmpty) continue;
        final edges = await _scanFrame(bytes);
        if (edges != null) frames.add(edges);
      } catch (e) {
        final msg = e.toString();
        // Early-exit if the player was disposed: getting a sample request
        // during teardown is a race, not a bug, and asking for the
        // remaining samples produces log spam. Bail out gracefully once.
        if (msg.contains('has been disposed')) {
          // ignore: avoid_print
          print(
            '[BlackBarDetector] player disposed mid-detection, '
            'returning partial result (${frames.length}/$samples samples)',
          );
          break;
        }
        // ignore: avoid_print
        print('[BlackBarDetector] screenshot/scan failed (sample $i): $e');
      }
    }
    if (frames.isEmpty) return null;
    final w = frames.first.width;
    final h = frames.first.height;
    final top = _mode(frames.map((f) => f.top).toList());
    final bottom = _mode(frames.map((f) => f.bottom).toList());
    final left = _mode(frames.map((f) => f.left).toList());
    final right = _mode(frames.map((f) => f.right).toList());
    return BlackBarResult(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      frameWidth: w,
      frameHeight: h,
      samples: frames.length,
    );
  }

  /// Returns the most frequent value in a list of 0-1 fractions. Buckets
  /// into 1% bins (e.g. 0.127, 0.128, 0.129 all fall in bucket 13). On a
  /// tie the smallest bucket wins (a more conservative estimate - enough
  /// to crop the real bar but not enough to eat into the content).
  double _mode(List<double> values) {
    if (values.isEmpty) return 0;
    final buckets = <int, int>{};
    for (final v in values) {
      final bucket = (v * 100).round();
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }
    final entries = buckets.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value); // count desc
        if (cmp != 0) return cmp;
        return a.key.compareTo(b.key); // bucket asc on tie
      });
    return entries.first.key / 100.0;
  }

  Future<_FrameEdges?> _scanFrame(Uint8List jpegBytes) async {
    final codec = await ui.instantiateImageCodec(jpegBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    codec.dispose();
    if (byteData == null) return null;
    final pixels = byteData.buffer.asUint8List();

    final maxRows = (height * maxScanFraction).round();
    final maxCols = (width * maxScanFraction).round();

    // Top edge: go down to the first non-black row.
    int topPx = 0;
    for (var y = 0; y < maxRows; y++) {
      if (_isRowBlack(pixels, width, y)) {
        topPx = y + 1;
      } else {
        break;
      }
    }
    // Bottom edge.
    int bottomPx = 0;
    for (var y = 0; y < maxRows; y++) {
      final row = height - 1 - y;
      if (_isRowBlack(pixels, width, row)) {
        bottomPx = y + 1;
      } else {
        break;
      }
    }
    // Left edge.
    int leftPx = 0;
    for (var x = 0; x < maxCols; x++) {
      if (_isColBlack(pixels, width, height, x)) {
        leftPx = x + 1;
      } else {
        break;
      }
    }
    // Right edge.
    int rightPx = 0;
    for (var x = 0; x < maxCols; x++) {
      final col = width - 1 - x;
      if (_isColBlack(pixels, width, height, col)) {
        rightPx = x + 1;
      } else {
        break;
      }
    }

    return _FrameEdges(
      topPx / height,
      bottomPx / height,
      leftPx / width,
      rightPx / width,
      width,
      height,
    );
  }

  bool _isRowBlack(Uint8List rgba, int width, int y) {
    final start = y * width * 4;
    final end = start + width * 4;
    var dark = 0;
    var counted = 0;
    // Instead of scanning every pixel, skip by 2 (enough for edge
    // detection and 2x faster).
    for (var i = start; i < end; i += 8) {
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      final luma = (r * 299 + g * 587 + b * 114) ~/ 1000;
      if (luma <= luminanceThreshold) dark++;
      counted++;
    }
    return counted > 0 && dark / counted >= rowBlackRatio;
  }

  bool _isColBlack(Uint8List rgba, int width, int height, int x) {
    var dark = 0;
    var counted = 0;
    // Likewise, skip by 2 rows.
    for (var y = 0; y < height; y += 2) {
      final i = (y * width + x) * 4;
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      final luma = (r * 299 + g * 587 + b * 114) ~/ 1000;
      if (luma <= luminanceThreshold) dark++;
      counted++;
    }
    return counted > 0 && dark / counted >= rowBlackRatio;
  }
}
