import 'package:flutter/material.dart';

import '../../core/theme/agora_colors.dart';
import '../../core/theme/agora_radius.dart';
import '../../core/theme/agora_spacing.dart';
import '../../core/theme/agora_typography.dart';
import 'agora_button.dart';

/// Agora Centered Loading Indicator
class AgoraLoadingIndicator extends StatelessWidget {
  const AgoraLoadingIndicator({
    super.key,
    this.message,
    this.color = AgoraColors.aegean,
  });

  final String? message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AgoraSpacing.md),
            Text(
              message!,
              style: AgoraTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Agora Empty State View
class AgoraEmptyState extends StatelessWidget {
  const AgoraEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AgoraSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AgoraColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AgoraColors.navySubtle),
            ),
            const SizedBox(height: AgoraSpacing.lg),
            Text(
              title,
              style: AgoraTypography.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AgoraSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                style: AgoraTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AgoraSpacing.xl),
              AgoraButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AgoraButtonVariant.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Agora Error State View
class AgoraErrorView extends StatelessWidget {
  const AgoraErrorView({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AgoraSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AgoraColors.errorContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 28,
                color: AgoraColors.error,
              ),
            ),
            const SizedBox(height: AgoraSpacing.md),
            Text(
              title,
              style: AgoraTypography.headlineMedium.copyWith(
                color: AgoraColors.navyDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AgoraSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                style: AgoraTypography.bodyMedium.copyWith(
                  color: AgoraColors.navyMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AgoraSpacing.lg),
              AgoraButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: onRetry,
                variant: AgoraButtonVariant.outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Agora In-Line Banner (Information / Warning / Notice)
class AgoraBanner extends StatelessWidget {
  const AgoraBanner({
    super.key,
    required this.text,
    this.icon,
    this.backgroundColor = AgoraColors.aegeanContainer,
    this.textColor = AgoraColors.aegeanDark,
    this.borderColor = AgoraColors.aegeanContainerBorder,
    this.action,
  });

  final String text;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AgoraSpacing.md,
        vertical: AgoraSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AgoraRadius.borderMd,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: AgoraSpacing.sm),
          ],
          Expanded(
            child: Text(
              text,
              style: AgoraTypography.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AgoraSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}
