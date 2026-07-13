import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigation double-tap guard. After pressing play on a detail page,
/// the route has not mounted yet, so the user can press the button
/// again; that would push the player route twice and two mpv instances
/// would play at once. We keep the last push timestamp globally and
/// swallow repeat taps within 800ms to prevent this.
///
/// The scope is the entire process life - no need for a per-route flag
/// because the user cannot trigger two separate buttons within 800ms
/// (average human reflex is 250ms; a double tap is typically <300ms).
class NavThrottle {
  static DateTime? _lastNav;

  /// Returns `true` and advances the timestamp if [cooldown] has passed
  /// since the previous navigation; otherwise returns `false` (the caller
  /// should cancel the navigation).
  static bool allow({Duration cooldown = const Duration(milliseconds: 400)}) {
    final now = DateTime.now();
    final last = _lastNav;
    if (last != null && now.difference(last) < cooldown) {
      return false;
    }
    _lastNav = now;
    return true;
  }

  /// Test/manual reset.
  static void reset() {
    _lastNav = null;
  }
}

extension NavThrottleContext on BuildContext {
  /// Same signature as `context.push`; but if called again within the
  /// [NavThrottle] limit it does nothing and returns `null`. Call this
  /// everywhere exposed to double-press risk, such as the play/resume
  /// buttons on a detail page.
  Future<T?> pushOnce<T extends Object?>(String location, {Object? extra}) {
    if (!NavThrottle.allow()) return Future<T?>.value(null);
    return push<T>(location, extra: extra);
  }
}

extension NavThrottleRouter on GoRouter {
  /// pushOnce equivalent for `GoRouter.of(context).push`. In places like
  /// the live TV / discover tab we use, GoRouter is referenced directly;
  /// this variant is for that instead of the BuildContext extension.
  Future<T?> pushOnce<T extends Object?>(String location, {Object? extra}) {
    if (!NavThrottle.allow()) return Future<T?>.value(null);
    return push<T>(location, extra: extra);
  }
}
