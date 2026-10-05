import 'package:flutter/material.dart';

import '../../core/theme/agora_colors.dart';
import '../../core/theme/agora_radius.dart';
import '../../core/theme/agora_spacing.dart';

/// Agora Card Component
///
/// Clean, whitewashed surface card with subtle border and optional highlight.
class AgoraCard extends StatelessWidget {
  const AgoraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AgoraSpacing.md),
    this.onTap,
    this.backgroundColor = AgoraColors.surface,
    this.borderColor = AgoraColors.surfaceBorder,
    this.borderRadius = AgoraRadius.borderMd,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color borderColor;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    return card;
  }
}
