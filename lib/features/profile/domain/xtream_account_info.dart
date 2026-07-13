/// Subscription/account snapshot for an Xtream source. Built from the
/// `user_info` + `server_info` blocks of the `player_api.php` auth call;
/// fields are optional because not every panel returns the full set.
class XtreamAccountInfo {
  final String sourceId;
  final String sourceName;
  final String? username;
  final String? status;
  final bool isTrial;
  final DateTime? expiresAt;
  final int? maxConnections;
  final int? activeConnections;
  final List<String> allowedFormats;
  final String? serverUrl;
  final String? timezone;

  const XtreamAccountInfo({
    required this.sourceId,
    required this.sourceName,
    this.username,
    this.status,
    this.isTrial = false,
    this.expiresAt,
    this.maxConnections,
    this.activeConnections,
    this.allowedFormats = const [],
    this.serverUrl,
    this.timezone,
  });

  /// Whole days remaining until [expiresAt]. Negative if already past.
  /// Null when the panel didn't supply an expiry (lifetime accounts).
  int? get daysLeft {
    final e = expiresAt;
    if (e == null) return null;
    return e.difference(DateTime.now()).inDays;
  }

  bool get isExpired {
    final e = expiresAt;
    if (e == null) return false;
    return e.isBefore(DateTime.now());
  }
}
