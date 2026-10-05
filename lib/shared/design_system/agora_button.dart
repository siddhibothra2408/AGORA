import 'package:flutter/material.dart';

import '../../core/theme/agora_colors.dart';
import '../../core/theme/agora_radius.dart';
import '../../core/theme/agora_spacing.dart';
import '../../core/theme/agora_typography.dart';

enum AgoraButtonVariant { primary, secondary, outlined, ghost, gold }

/// Agora Unified Button Component
///
/// Enforces minimum 48dp touch target, text scaling compliance,
/// and distinct visual hierarchy.
class AgoraButton extends StatelessWidget {
  const AgoraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AgoraButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = false,
    this.height = AgoraSpacing.minTouchTarget,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AgoraButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    Color bg;
    Color fg;
    BorderSide? border;

    switch (variant) {
      case AgoraButtonVariant.primary:
        bg = AgoraColors.aegean;
        fg = Colors.white;
        border = null;
        break;
      case AgoraButtonVariant.secondary:
        bg = AgoraColors.surfaceContainer;
        fg = AgoraColors.navyDark;
        border = const BorderSide(color: AgoraColors.surfaceBorder);
        break;
      case AgoraButtonVariant.outlined:
        bg = Colors.transparent;
        fg = AgoraColors.aegean;
        border = const BorderSide(color: AgoraColors.surfaceBorder, width: 1.2);
        break;
      case AgoraButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AgoraColors.navy;
        border = null;
        break;
      case AgoraButtonVariant.gold:
        bg = AgoraColors.goldContainer;
        fg = AgoraColors.goldDark;
        border = const BorderSide(color: AgoraColors.goldContainerBorder);
        break;
    }

    if (isDisabled) {
      bg = bg == Colors.transparent
          ? Colors.transparent
          : AgoraColors.surfaceContainerHigh;
      fg = AgoraColors.navyDisabled;
      if (border != null) {
        border = const BorderSide(color: AgoraColors.surfaceBorderSubtle);
      }
    }

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          Padding(
            padding: const EdgeInsets.only(right: AgoraSpacing.xs),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            ),
          )
        else if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: AgoraSpacing.xs),
        ],
        Text(
          label,
          style: AgoraTypography.labelLarge.copyWith(color: fg),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final button = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: AgoraRadius.borderMd,
        side: border ?? BorderSide.none,
      ),
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: AgoraRadius.borderMd,
        child: Container(
          constraints: BoxConstraints(minWidth: 88, minHeight: height),
          padding: const EdgeInsets.symmetric(
            horizontal: AgoraSpacing.lg,
            vertical: AgoraSpacing.xs,
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
