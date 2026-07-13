import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Open-source build: subscription / paywall / license gating is fully
/// removed. All features are public and free.
///
/// These types and providers are kept only to keep the old call sites (UI
/// cards, player controls) working untouched; they all always return
/// "full access". No server verification is done.
class ProStatus {
  final bool isPro;
  final DateTime? expiresAt;
  final DateTime? lastVerifiedAt;
  final String? productId;

  const ProStatus({
    required this.isPro,
    this.expiresAt,
    this.lastVerifiedAt,
    this.productId,
  });

  /// Always valid - all gates are open.
  bool get isValid => true;
}

class ProStatusNotifier extends AsyncNotifier<ProStatus> {
  @override
  Future<ProStatus> build() async {
    return ProStatus(
      isPro: true,
      expiresAt: DateTime(2099),
      lastVerifiedAt: DateTime(2099),
    );
  }
}

final proStatusProvider =
    AsyncNotifierProvider<ProStatusNotifier, ProStatus>(ProStatusNotifier.new);

/// Synchronous access for UI gates - always full access.
final isProProvider = Provider<bool>((ref) => true);
