import 'dart:async';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';

class DownloadProgress {
  final int received;
  final int? total;
  final double? fraction;

  /// Instantaneous speed (bytes/second). May be `null` on the first emit - no sample yet.
  final double? bytesPerSecond;
  const DownloadProgress({
    required this.received,
    this.total,
    this.fraction,
    this.bytesPerSecond,
  });
}

class DownloadResult {
  final File file;
  final bool partial;
  const DownloadResult(this.file, {this.partial = false});
}

class DownloadException implements Exception {
  final String message;
  final bool unsupportedFormat;
  final bool cancelled;
  const DownloadException(
    this.message, {
    this.unsupportedFormat = false,
    this.cancelled = false,
  });

  @override
  String toString() => 'DownloadException($message)';
}

/// IPTV servers hand out only a small slice of the file (usually
/// 5-20 MB) in a single HTTP request and then close the connection
/// (anti-leech). So each time we open a new connection with
/// `Range: bytes=X-` and resume from where we left off.
class DownloadService {
  HttpClient? _activeClient;
  bool _cancelled = false;

  bool get isDownloading => _activeClient != null && !_cancelled;

  Future<Directory> ensureDirectory() async {
    Directory? base;
    final home = Platform.environment['HOME'];
    if (home != null) {
      final candidate = Directory(p.join(home, 'Documents'));
      if (await candidate.exists()) base = candidate;
    }
    base ??= await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(base.path, AppConfig.I.storageSlug, 'downloads'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _sanitize(String name) => name
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _extensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final dot = last.lastIndexOf('.');
      if (dot != -1 && dot < last.length - 1) {
        final ext = last.substring(dot + 1).toLowerCase();
        if (ext.length <= 4 && RegExp(r'^[a-z0-9]+$').hasMatch(ext)) return ext;
      }
    } catch (_) {
      /* fall through */
    }
    return 'mp4';
  }

  HttpClient _newClient() {
    final c = HttpClient();
    c.connectionTimeout = const Duration(seconds: 15);
    // Same UA as mpv - most IPTV servers reject any UA other than
    // VLC/Lavf with a 403.
    c.userAgent = 'VLC/3.0.20 LibVLC/3.0.20';
    return c;
  }

  Future<DownloadResult> download({
    required String url,
    String? title,
    void Function(DownloadProgress)? onProgress,
  }) async {
    final ext = _extensionFromUrl(url);
    if (ext == 'm3u8' || ext == 'm3u') {
      throw const DownloadException('HLS / playlist', unsupportedFormat: true);
    }

    cancel();
    _cancelled = false;

    final dir = await ensureDirectory();
    final baseName = (title == null || title.isEmpty)
        ? AppConfig.I.storageSlug
        : _sanitize(title);
    // On a collision, number them as "Film (1).mp4", "Film (2).mp4".
    String fileName = '$baseName.$ext';
    String fullPath = p.join(dir.path, fileName);
    var dup = 1;
    while (await File(fullPath).exists()) {
      fileName = '$baseName ($dup).$ext';
      fullPath = p.join(dir.path, fileName);
      dup++;
    }

    final uri = Uri.parse(url);
    final file = File(fullPath);
    final sink = file.openWrite();
    int received = 0;
    int? total;
    int attempts = 0;
    // Hard upper bound: 10000 slices * 5MB average ≈ 50 GB. Keeps a
    // runaway loop from flowing to infinity.
    const maxAttempts = 10000;
    bool serverSupportsRange = true;
    Object? lastError;

    // Progress throttle + cumulative average speed since the start.
    //   bps = received / elapsed
    //   eta = (total - received) / bps   (computed on the UI side)
    // A sliding window was jittery; the cumulative average both matches
    // the user's formula and is deterministic.
    final downloadStartedAt = DateTime.now();
    var lastEmitAt = downloadStartedAt;
    const emitInterval = Duration(milliseconds: 400);

    void emitProgress({bool force = false}) {
      final now = DateTime.now();
      if (!force && now.difference(lastEmitAt) < emitInterval) return;
      lastEmitAt = now;

      final elapsedSecs =
          now.difference(downloadStartedAt).inMicroseconds / 1e6;
      double? bps;
      // Very little data in the first second - skip it so the number does not look jittery.
      if (elapsedSecs >= 1.0 && received > 0) {
        bps = received / elapsedSecs;
      }

      final t = total;
      onProgress?.call(
        DownloadProgress(
          received: received,
          total: t,
          fraction: t == null
              ? null
              : (received / t).clamp(0.0, 1.0).toDouble(),
          bytesPerSecond: bps,
        ),
      );
    }

    try {
      while (true) {
        if (_cancelled) break;
        attempts++;
        if (attempts > maxAttempts) {
          // ignore: avoid_print
          print('[Download] max attempts reached at $received bytes');
          break;
        }

        final client = _newClient();
        _activeClient = client;
        bool segmentHadData = false;
        try {
          final req = await client.getUrl(uri);
          req.headers.set(HttpHeaders.acceptHeader, '*/*');
          if (received > 0) {
            req.headers.set(HttpHeaders.rangeHeader, 'bytes=$received-');
          }
          req.followRedirects = true;
          req.maxRedirects = 8;

          final res = await req.close();
          final code = res.statusCode;

          if (attempts == 1) {
            if (code < 200 || code >= 300) {
              try {
                await res.drain<void>();
              } catch (_) {}
              throw DownloadException('HTTP $code');
            }
            // Total: first Content-Range, then Content-Length.
            final cr = res.headers.value(HttpHeaders.contentRangeHeader);
            if (cr != null) {
              final m = RegExp(r'/(\d+)').firstMatch(cr);
              if (m != null) total = int.tryParse(m.group(1)!);
            }
            total ??= res.contentLength > 0 ? res.contentLength : null;
          } else {
            // We requested a Range. We expect 206; if 200 comes back the
            // server does not support Range - it sends the whole file from
            // the start; stop so it does not overlap what we already wrote.
            if (code == 200) {
              serverSupportsRange = false;
              try {
                await res.drain<void>();
              } catch (_) {}
              break;
            }
            if (code != 206) {
              try {
                await res.drain<void>();
              } catch (_) {}
              throw DownloadException('HTTP $code');
            }
            // If total is unknown, confirm it from Content-Range.
            if (total == null) {
              final cr = res.headers.value(HttpHeaders.contentRangeHeader);
              if (cr != null) {
                final m = RegExp(r'/(\d+)').firstMatch(cr);
                if (m != null) total = int.tryParse(m.group(1)!);
              }
            }
          }

          final completer = Completer<void>();
          late StreamSubscription<List<int>> sub;
          sub = res.listen(
            (chunk) {
              if (_cancelled) return;
              sink.add(chunk);
              received += chunk.length;
              segmentHadData = true;
              emitProgress();
            },
            onError: (Object e, StackTrace st) {
              if (!completer.isCompleted) completer.completeError(e, st);
            },
            onDone: () {
              if (!completer.isCompleted) completer.complete();
            },
            cancelOnError: true,
          );

          try {
            await completer.future;
          } catch (e) {
            await sub.cancel();
            lastError = e;
            // The connection closed midway; the loop will continue with a new segment.
          }
        } finally {
          if (identical(_activeClient, client)) _activeClient = null;
          try {
            client.close(force: true);
          } catch (_) {}
        }

        if (_cancelled) break;
        final t = total;
        if (t != null && received >= t) break;
        // Stop to avoid an infinite loop if Range is unsupported or there
        // was no progress at all in this segment.
        if (!serverSupportsRange) break;
        if (!segmentHadData) break;
        // Let the server breathe - aggressive parallel requests trigger anti-leech.
        await Future.delayed(const Duration(milliseconds: 200));
      }

      emitProgress(force: true);
      await sink.close();

      if (_cancelled) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        throw const DownloadException('cancelled', cancelled: true);
      }

      // ignore: avoid_print
      print(
        '[Download] done received=$received total=${total ?? "?"} '
        'attempts=$attempts',
      );

      final tFinal = total;
      final isPartial = tFinal != null && received < tFinal;
      if (isPartial && received < 1024 * 1024) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        throw DownloadException(
          lastError?.toString() ?? 'incomplete ($received bytes)',
        );
      }
      return DownloadResult(file, partial: isPartial);
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      if (_cancelled) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        throw const DownloadException('cancelled', cancelled: true);
      }
      if (e is DownloadException) rethrow;
      // ignore: avoid_print
      print('[Download] fatal err=$e received=$received');
      throw DownloadException(e.toString());
    }
  }

  void cancel() {
    _cancelled = true;
    final c = _activeClient;
    if (c != null) {
      try {
        c.close(force: true);
      } catch (_) {}
    }
    _activeClient = null;
  }
}
