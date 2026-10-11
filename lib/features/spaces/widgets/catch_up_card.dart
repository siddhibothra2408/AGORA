import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_radius.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../models/catch_up_summary.dart';

/// Catch-Up Card Component
///
/// Principles:
/// - Strictly non-AI (Aegean Blue aesthetic, NOT gold).
/// - Dismissible by the user.
/// - Shows deterministic changes since `lastReadAt`.
class CatchUpCard extends StatelessWidget {
  const CatchUpCard({
    super.key,
    required this.spaceId,
    required this.summary,
    required this.onDismiss,
  });

  final String spaceId;
  final CatchUpSummary summary;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (!summary.shouldDisplay) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AgoraSpacing.md,
        vertical: AgoraSpacing.xs,
      ),
      padding: const EdgeInsets.all(AgoraSpacing.md),
      decoration: BoxDecoration(
        color: AgoraColors.aegeanContainer,
        borderRadius: AgoraRadius.borderMd,
        border: Border.all(color: AgoraColors.aegeanContainerBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.update_outlined,
                size: 18,
                color: AgoraColors.aegeanDark,
              ),
              const SizedBox(width: AgoraSpacing.xs),
              Expanded(
                child: Text(
                  'Since you were last here',
                  style: AgoraTypography.titleMedium.copyWith(
                    color: AgoraColors.aegeanDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Semantics(
                label: 'Dismiss catch-up summary',
                button: true,
                child: InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: AgoraColors.aegeanDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AgoraSpacing.xs),
          Text(
            'Activity recorded in this space since your last visit:',
            style: AgoraTypography.bodySmall.copyWith(
              color: AgoraColors.aegeanDark,
            ),
          ),
          const SizedBox(height: AgoraSpacing.sm),
          Wrap(
            spacing: AgoraSpacing.xs,
            runSpacing: AgoraSpacing.xxs,
            children: [
              if (summary.newMessagesCount > 0)
                _CatchUpChip(
                  icon: Icons.chat_bubble_outline,
                  label: '${summary.newMessagesCount} new messages',
                ),
              if (summary.itemsCreatedCount > 0)
                _CatchUpChip(
                  icon: Icons.add_task,
                  label: '${summary.itemsCreatedCount} items created',
                ),
              if (summary.itemsAssignedToYouCount > 0)
                _CatchUpChip(
                  icon: Icons.person_pin_outlined,
                  label: '${summary.itemsAssignedToYouCount} assigned to you',
                ),
              if (summary.decisionsMadeCount > 0)
                _CatchUpChip(
                  icon: Icons.gavel_outlined,
                  label: '${summary.decisionsMadeCount} decisions recorded',
                ),
              if (summary.itemsCompletedCount > 0)
                _CatchUpChip(
                  icon: Icons.check_circle_outline,
                  label: '${summary.itemsCompletedCount} completed',
                ),
              if (summary.handoffsRunCount > 0)
                Semantics(
                  button: true,
                  label:
                      'View ${summary.handoffsRunCount} handoffs in AI Ledger',
                  child: InkWell(
                    onTap: () => context.go('/spaces/$spaceId/pulse'),
                    borderRadius: BorderRadius.circular(12),
                    child: _CatchUpChip(
                      icon: Icons.history_edu,
                      label:
                          '${summary.handoffsRunCount} handoffs run (view ledger)',
                      highlight: true,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatchUpChip extends StatelessWidget {
  const _CatchUpChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? AgoraColors.surface
            : AgoraColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? AgoraColors.aegean
              : AgoraColors.aegeanContainerBorder,
          width: highlight ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AgoraColors.aegeanDark),
          const SizedBox(width: 4),
          Text(
            label,
            style: AgoraTypography.bodySmall.copyWith(
              color: AgoraColors.aegeanDark,
              fontSize: 11,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
