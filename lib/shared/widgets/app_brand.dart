import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';

/// Wordmark used in the side rail header. Plain text with a strong/light
/// weight split - the first two characters render in the accent colour at
/// bold weight, the remainder in the regular text colour at light weight.
class AppBrand extends StatelessWidget {
  final double size;
  final bool compact;
  const AppBrand({super.key, this.size = 22, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return compact
        ? _Wordmark(size: size, onlyShort: true)
        : _Wordmark(size: size);
  }
}

class _Wordmark extends StatelessWidget {
  final double size;
  final bool onlyShort;
  const _Wordmark({required this.size, this.onlyShort = false});

  @override
  Widget build(BuildContext context) {
    final name = AppConfig.I.appName;
    // The first 2 characters are in the accent color AND larger/bolder - e.g.
    // for "IPdigi" the "IP" head is emphasized and the "digi" tail stays
    // normal. For names shorter than 2 characters the whole word keeps the accent style.
    final headLen = name.length >= 3 ? 2 : name.length;
    final head = name.substring(0, headLen);
    final tail = name.substring(headLen);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: head,
            style: TextStyle(
              color: AppColors.accent,
              fontSize: size * 1.45,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.0,
            ),
          ),
          if (!onlyShort && tail.isNotEmpty)
            TextSpan(
              text: tail,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: size,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.4,
                height: 1.0,
              ),
            ),
        ],
      ),
    );
  }
}

