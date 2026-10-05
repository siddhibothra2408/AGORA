import 'package:flutter/material.dart';

import '../../core/theme/agora_colors.dart';
import '../../core/theme/agora_radius.dart';
import '../../core/theme/agora_spacing.dart';
import '../../core/theme/agora_typography.dart';

enum AgoraBadgeVariant {
  neutral,
  aegean,
  success,
  warning,
  error,
  withhold,
  gold,
}

/// Agora Badge Component
class AgoraBadge extends StatelessWidget {
  const AgoraBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = AgoraBadgeVariant.neutral,
  });

  final String label;
  final IconData? icon;
  final AgoraBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case AgoraBadgeVariant.neutral:
        bg = AgoraColors.surfaceContainer;
        fg = AgoraColors.navyMuted;
        border = AgoraColors.surfaceBorder;
        break;
      case AgoraBadgeVariant.aegean:
        bg = AgoraColors.aegeanContainer;
        fg = AgoraColors.aegeanDark;
        border = AgoraColors.aegeanContainerBorder;
        break;
      case AgoraBadgeVariant.success:
        bg = AgoraColors.successContainer;
        fg = AgoraColors.success;
        border = AgoraColors.successBorder;
        break;
      case AgoraBadgeVariant.warning:
        bg = AgoraColors.warningContainer;
        fg = AgoraColors.warning;
        border = AgoraColors.warningBorder;
        break;
      case AgoraBadgeVariant.error:
        bg = AgoraColors.errorContainer;
        fg = AgoraColors.error;
        border = AgoraColors.errorBorder;
        break;
      case AgoraBadgeVariant.withhold:
        bg = AgoraColors.withholdContainer;
        fg = AgoraColors.withhold;
        border = AgoraColors.withholdBorder;
        break;
      case AgoraBadgeVariant.gold:
        bg = AgoraColors.goldContainer;
        fg = AgoraColors.goldDark;
        border = AgoraColors.goldContainerBorder;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AgoraSpacing.xs,
        vertical: 3.0,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AgoraRadius.borderSm,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: AgoraSpacing.xxs),
          ],
          Text(
            label,
            style: AgoraTypography.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Specialized Consent Badge
class AgoraConsentBadge extends StatelessWidget {
  const AgoraConsentBadge({super.key, required this.isWithheld});

  final bool isWithheld;

  @override
  Widget build(BuildContext context) {
    if (isWithheld) {
      return const AgoraBadge(
        label: 'AI WITHHELD',
        icon: Icons.shield_outlined,
        variant: AgoraBadgeVariant.withhold,
      );
    }
    return const AgoraBadge(
      label: 'ELIGIBLE',
      icon: Icons.check_circle_outline,
      variant: AgoraBadgeVariant.neutral,
    );
  }
}

/// Specialized AI Provenance Badge (Strict Gold Theme)
class AgoraAiBadge extends StatelessWidget {
  const AgoraAiBadge({
    super.key,
    this.label = 'AI PROPOSAL',
    this.icon = Icons.auto_awesome_outlined,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AgoraBadge(
      label: label,
      icon: icon,
      variant: AgoraBadgeVariant.gold,
    );
  }
}
