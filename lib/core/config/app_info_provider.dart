import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Runtime metadata for the app (version + build number + package
/// name). `package_info_plus` reads from the platform-specific
/// plist/manifest; it reflects our pubspec.yaml version (`1.0.4`). The
/// sidebar footer line and profile page watch this.
final appInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});
