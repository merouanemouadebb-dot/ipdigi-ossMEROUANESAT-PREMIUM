import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Small bordered chip that displays a localized age-rating string such as
/// "13+", "PG-13", or "TP". The label is whatever TMDB returned for the
/// user's region - we don't translate it because rating systems differ per
/// country and the raw label is the universally meaningful one.
class CertificationBadge extends StatelessWidget {
  final String label;
  const CertificationBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.7),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
