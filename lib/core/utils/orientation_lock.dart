import 'dart:io';

import 'package:flutter/services.dart';

import '../config/platform_info.dart';

/// Ekran yonu kilidi. Telefonda gezinme sirasinda portrait kilitli,
/// player'da (video) serbest. iPad/tablet her zaman serbest (tablet iki
/// yonde de kullanilir). Desktop'ta orientation kavrami yok, no-op.
///
/// isTablet karari Material breakpoint'i (shortestSide >= 600) ile
/// caller tarafinda MediaQuery'den hesaplanir; bu sinif context almaz
/// (player dispose'da context guvenilir degil).
class OrientationLock {
  // TV (Android TV / Google TV) her zaman yataydir ve donanim orientation
  // kilidini desteklemez. Orada setPreferredOrientations(_all) cagrisi
  // portrait'e izin verince genis TV ekrani dar/portrait moda dusup
  // layout'u bozuyordu (nav rail siser, kategori paneli tasar). Bu yuzden
  // TV'de tum orientation islemleri no-op.
  static bool get _mobile =>
      !PlatformInfo.isTv && (Platform.isIOS || Platform.isAndroid);

  static const _all = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// Gezinme (player disi) icin. Telefon: portrait kilit. Tablet: serbest.
  static Future<void> browsing({required bool isTablet}) async {
    if (!_mobile) return;
    if (isTablet) {
      await SystemChrome.setPreferredOrientations(_all);
    } else {
      await SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.portraitUp],
      );
    }
  }

  /// Player (video) icin: her cihazda tum yonler serbest.
  static Future<void> player() async {
    if (!_mobile) return;
    await SystemChrome.setPreferredOrientations(_all);
  }

  /// Player'daki "yatay cevir / tam ekran" butonu icin. Sistem donme
  /// kilidi (auto-rotate kapali) acik olsa bile uygulama icinde yatayi
  /// zorlar - setPreferredOrientations'i tek yone sabitlemek sistem
  /// kilidini asar (issue #2/1). Geri donus icin [player] cagrilir.
  static Future<void> forceLandscape() async {
    if (!_mobile) return;
    await SystemChrome.setPreferredOrientations(
      const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
  }
}
