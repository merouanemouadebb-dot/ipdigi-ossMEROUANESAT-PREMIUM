import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/i18n.dart';
import '../../core/theme/app_theme.dart';

/// A full-screen viewer for gallery images. Swipe left/right with a
/// PageView; two tool buttons at the top (download + close). The design is
/// deliberately minimal: fully black background, controls as a transparent
/// bar - so the image stays in front.
class ImageViewer extends ConsumerStatefulWidget {
  final List<String> images;
  final int initialIndex;
  /// The content name the downloaded files belong to (e.g. "The Dark
  /// Tower"). Foldered as: Documents/<appSlug>/Photos/<itemTitle>/
  /// <filename>.jpg. If null, saved directly into the Photos folder.
  final String? downloadTitle;

  const ImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.downloadTitle,
  });

  /// Push fullscreen route. Returns when user closes.
  static Future<void> show(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    String? downloadTitle,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => ImageViewer(
          images: images,
          initialIndex: initialIndex,
          downloadTitle: downloadTitle,
        ),
        transitionsBuilder: (_, anim, _, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  ConsumerState<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends ConsumerState<ImageViewer> {
  late final PageController _controller;
  late int _index;
  bool _downloading = false;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _toast = null);
    });
  }

  Future<void> _download() async {
    if (_downloading) return;
    if (_index < 0 || _index >= widget.images.length) return;
    final url = widget.images[_index];
    // Security: only http/https are accepted. Schemes like file://, data:,
    // content:// are cancelled immediately because they would open a local
    // file leak or SSRF surface. If the URL cannot be parsed, the download
    // is also rejected.
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      _showToast(ref.tr('imageViewer.unsupported'));
      return;
    }
    setState(() => _downloading = true);
    try {
      final dir = await _ensurePhotosDir();
      final ext = _extensionFromUrl(url);
      final filename = '${_baseName()}_${_index + 1}.$ext';
      // The normalized full path must stay under the target folder; even
      // though _baseName already neutralizes escapes, we apply an extra
      // isWithin check as defense-in-depth.
      final normalized = p.normalize(p.join(dir.path, filename));
      if (!p.isWithin(dir.path, normalized) &&
          p.canonicalize(p.dirname(normalized)) !=
              p.canonicalize(dir.path)) {
        _showToast(ref.tr('imageViewer.invalidPath'));
        return;
      }
      final file = File(normalized);
      final dio = Dio();
      await dio.download(url, file.path);
      if (!mounted) return;
      _showToast(ref.tr('imageViewer.saved', {'name': p.basename(file.path)}));
    } catch (e) {
      if (!mounted) return;
      _showToast(ref.tr('imageViewer.downloadFailed'));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _baseName() {
    final raw = widget.downloadTitle?.trim();
    if (raw == null || raw.isEmpty) return 'image';
    // Filesystem-safe slug:
    //  - convert separator characters ('/ \ : * ? " < > |') to underscores
    //  - close path traversal via the parent-dir segment '..'
    //  - collapse whitespace
    //  - if the result is still '.' or '..', use a generic name
    var s = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\.\.+'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // A leading/trailing dot is also unsafe: strip variants like ".hidden",
    // "name." - some filesystems do not accept a trailing dot.
    while (s.startsWith('.')) {
      s = s.substring(1);
    }
    while (s.endsWith('.')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.isEmpty) return 'image';
    return s;
  }

  Future<Directory> _ensurePhotosDir() async {
    Directory? base;
    // Prefer the user's HOME/Documents first; if macOS is not sandboxed the
    // app can leave visible files here.
    final home = Platform.environment['HOME'];
    if (home != null) {
      final candidate = Directory(p.join(home, 'Documents'));
      if (await candidate.exists()) base = candidate;
    }
    base ??= await getApplicationDocumentsDirectory();
    final root =
        Directory(p.join(base.path, AppConfig.I.storageSlug, 'Photos'));
    final dir = widget.downloadTitle?.trim().isNotEmpty == true
        ? Directory(p.join(root.path, _baseName()))
        : root;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Derives the extension from the URL path; accepts only known image
  /// formats. Otherwise defaults to "jpg". This restriction prevents a
  /// double-extension like "cover.jpg.exe" from the server, or an arbitrary
  /// script extension, from being written to the filesystem.
  String _extensionFromUrl(String url) {
    const allowed = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'avif'};
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final dot = last.lastIndexOf('.');
      if (dot != -1 && dot < last.length - 1) {
        final ext = last.substring(dot + 1).toLowerCase();
        if (allowed.contains(ext)) return ext;
      }
    } catch (_) {/* fall through */}
    return 'jpg';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.92),
      body: Stack(
        children: [
          // Keyboard listener - ESC closes, left/right arrows change pages.
          Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(context).pop();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                if (_index > 0) {
                  _controller.previousPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  );
                }
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                if (_index < widget.images.length - 1) {
                  _controller.nextPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  );
                }
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  // With memCacheWidth, limit the decoded size held in RAM
                  // to the screen width; a 4K backdrop led to ~30MB decoded
                  // image per page, which could cause a crash especially
                  // under iOS memory pressure.
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final width = (MediaQuery.of(context).size.width * dpr)
                      .clamp(1.0, 2560.0)
                      .toInt();
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: widget.images[i],
                        fit: BoxFit.contain,
                        fadeInDuration: const Duration(milliseconds: 150),
                        memCacheWidth: width,
                        placeholder: (_, _) => const Center(
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                        errorWidget: (_, _, _) => const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white54,
                          size: 64,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Top toolbar: tool buttons only (download + close).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.images.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '${_index + 1} / ${widget.images.length}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: _downloading
                          ? ref.tr('imageViewer.downloading')
                          : ref.tr('imageViewer.download'),
                      icon: _downloading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: AppColors.accent,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.download_rounded,
                              color: Colors.white),
                      onPressed: _downloading ? null : _download,
                    ),
                    IconButton(
                      tooltip: ref.tr('common.close'),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_toast != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _toast!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
