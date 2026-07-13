import 'package:flutter/material.dart';

/// Wraps a hero widget so its opacity fades to zero as the parent
/// SliverAppBar collapses. Pass as `SliverAppBar.flexibleSpace`.
class FadingFlexibleSpace extends StatelessWidget {
  final double expandedHeight;
  final double collapsedHeight;
  final Widget child;
  const FadingFlexibleSpace({
    super.key,
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.biggest.height;
        final range = (expandedHeight - collapsedHeight);
        final t = range <= 0
            ? 1.0
            : ((h - collapsedHeight) / range).clamp(0.0, 1.0);
        return Opacity(opacity: Curves.easeIn.transform(t), child: child);
      },
    );
  }
}
