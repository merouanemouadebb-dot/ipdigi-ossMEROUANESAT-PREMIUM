import 'dart:convert';

import 'package:uuid/uuid.dart';

enum SourceKind { xtream, m3u, direct }

sealed class IptvSource {
  final String id;
  final String name;
  final DateTime createdAt;

  const IptvSource({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  SourceKind get kind;

  Map<String, dynamic> toConfigJson();

  String configJsonString() => jsonEncode(toConfigJson());

  static IptvSource fromRow({
    required String id,
    required String name,
    required String type,
    required String configJson,
    required DateTime createdAt,
  }) {
    final config = jsonDecode(configJson) as Map<String, dynamic>;
    switch (type) {
      case 'xtream':
        return XtreamSource(
          id: id,
          name: name,
          createdAt: createdAt,
          url: config['url'] as String,
          username: config['username'] as String,
          password: config['password'] as String,
        );
      case 'm3u':
        return M3uSource(
          id: id,
          name: name,
          createdAt: createdAt,
          urlOrPath: config['urlOrPath'] as String,
          epgUrl: config['epgUrl'] as String?,
        );
      case 'direct':
        return DirectUrlSource(
          id: id,
          name: name,
          createdAt: createdAt,
          url: config['url'] as String,
        );
      default:
        throw ArgumentError('Unknown source type: $type');
    }
  }

  /// Random id - a fallback only for cases where a deterministic id
  /// cannot be produced. The normal add flow uses [deterministicId].
  static String newId() => const Uuid().v4();

  /// DETERMINISTIC id derived from the source's connection details. When
  /// the same panel/m3u is added again it yields the same UUID; so the
  /// content id (`sourceId|streamId`) stays stable and ratings/watch
  /// history/favorites/watchlists do not break even if you delete and
  /// re-add the source.
  ///
  /// The seed does NOT include the password (Xtream): so the id does not
  /// break when the user changes their password. The host is reduced to
  /// scheme+host+port, and the m3u URL is cleaned from the blob
  /// ([cleanM3uUrl]).
  static String deterministicId({
    required SourceKind kind,
    required Map<String, dynamic> config,
  }) {
    final String seed;
    switch (kind) {
      case SourceKind.xtream:
        final host = _normHost(config['url'] as String);
        final user = (config['username'] as String).trim().toLowerCase();
        seed = 'xtream|$host|$user';
      case SourceKind.m3u:
        final url = cleanM3uUrl(config['urlOrPath'] as String)
            .trim()
            .toLowerCase();
        seed = 'm3u|$url';
      case SourceKind.direct:
        final url = (config['url'] as String).trim().toLowerCase();
        seed = 'direct|$url';
    }
    return const Uuid().v5(Namespace.url.value, seed);
  }

  /// Reduces the URL to scheme://host:port form; path, query and trailing
  /// slash are dropped. So that the same panel entered with different
  /// endpoints/parameters (get.php vs player_api.php) resolves to the
  /// same id.
  static String _normHost(String raw) {
    final u = Uri.tryParse(raw.trim());
    if (u == null || u.host.isEmpty) return raw.trim().toLowerCase();
    final port = u.hasPort ? ':${u.port}' : '';
    return '${u.scheme.toLowerCase()}://${u.host.toLowerCase()}$port';
  }

  /// Extracts the real m3u URL from a pasted m3u "blob" (like
  /// `<m3u url> EPG: <xmltv> Cpanel: <token>` copied from a panel page):
  /// starts at the first http(s), and cuts at the first whitespace, at an
  /// `epg:` / `cpanel:` / `m3u:` marker, or at the second http(s). A local
  /// file path or unknown format is returned untouched.
  static String cleanM3uUrl(String raw) {
    final s = raw.trim();
    final lower = s.toLowerCase();
    final start = lower.indexOf('http');
    if (start < 0) return s;
    var end = s.length;
    void cut(int idx) {
      if (idx >= 0 && idx < end) end = idx;
    }

    final ws = RegExp(r'\s').firstMatch(s.substring(start));
    if (ws != null) cut(start + ws.start);
    for (final marker in const [
      'epg:',
      'cpanel:',
      'm3u:',
      'http://',
      'https://',
    ]) {
      cut(lower.indexOf(marker, start + 4));
    }
    return s.substring(start, end);
  }
}

class XtreamSource extends IptvSource {
  final String url;
  final String username;
  final String password;

  const XtreamSource({
    required super.id,
    required super.name,
    required super.createdAt,
    required this.url,
    required this.username,
    required this.password,
  });

  @override
  SourceKind get kind => SourceKind.xtream;

  @override
  Map<String, dynamic> toConfigJson() => {
    'url': url,
    'username': username,
    'password': password,
  };
}

class M3uSource extends IptvSource {
  final String urlOrPath;
  final String? epgUrl;

  const M3uSource({
    required super.id,
    required super.name,
    required super.createdAt,
    required this.urlOrPath,
    this.epgUrl,
  });

  @override
  SourceKind get kind => SourceKind.m3u;

  @override
  Map<String, dynamic> toConfigJson() => {
    'urlOrPath': urlOrPath,
    if (epgUrl != null) 'epgUrl': epgUrl,
  };
}

class DirectUrlSource extends IptvSource {
  final String url;

  const DirectUrlSource({
    required super.id,
    required super.name,
    required super.createdAt,
    required this.url,
  });

  @override
  SourceKind get kind => SourceKind.direct;

  @override
  Map<String, dynamic> toConfigJson() => {'url': url};
}
