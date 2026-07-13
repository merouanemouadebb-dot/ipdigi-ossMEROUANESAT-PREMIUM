import 'dart:async';
import 'dart:io';

/// Local HTTP server that wraps the YouTube iframe embed in an HTML page
/// served over `http://127.0.0.1`. YouTube's embed gate refuses to play
/// from `file://` and `data:` URIs (the symptom is "Video unavailable -
/// error 152" inside the WebView) so embedding straight from
/// `InAppWebViewInitialData` always fails on macOS. Pointing the WebView
/// at a localhost URL gives it a trusted HTTP origin and the gate lets
/// the playback through.
class TrailerServer {
  static final TrailerServer instance = TrailerServer._();
  TrailerServer._();

  HttpServer? _server;
  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(_server!.forEach(_handle));
    // ignore: avoid_print
    print('[TrailerServer] listening on http://127.0.0.1:${_server!.port}');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// URL for the in-app trailer player.
  String urlFor(String videoId) =>
      'http://127.0.0.1:$port/trailer/$videoId';

  void _handle(HttpRequest req) {
    final match =
        RegExp(r'^/trailer/([A-Za-z0-9_-]{11})$').firstMatch(req.uri.path);
    if (match == null) {
      req.response.statusCode = 404;
      req.response.close();
      return;
    }
    final key = match.group(1)!;
    req.response.headers
      ..contentType = ContentType.html
      ..set('Cache-Control', 'no-store');
    req.response.write(_buildHtml(key));
    req.response.close();
  }

  String _buildHtml(String key) => '''
<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<style>
  html, body { margin: 0; padding: 0; background: #000; overflow: hidden; height: 100%; }
  .wrap { position: absolute; inset: 0; }
  iframe { width: 100%; height: 100%; border: 0; display: block; }
</style>
</head>
<body>
<div class="wrap">
  <iframe
    id="player"
    src="https://www.youtube.com/embed/$key?autoplay=1&modestbranding=1&rel=0&playsinline=1"
    title="YouTube video player"
    frameborder="0"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
    referrerpolicy="strict-origin-when-cross-origin"
    allowfullscreen></iframe>
</div>
</body>
</html>
''';
}
