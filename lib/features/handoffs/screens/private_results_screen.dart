import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_badge.dart';
import '../../../shared/design_system/agora_card.dart';
import '../../../shared/design_system/agora_states.dart';
import '../../items/models/item.dart';
import '../models/proposal.dart';
import '../repositories/handoff_repository.dart';

class PrivateResultsScreen extends ConsumerWidget {
  const PrivateResultsScreen({
    super.key,
    required this.spaceId,
    required this.handoffId,
  });

  final String spaceId;
  final String handoffId;

  static void show(
    BuildContext context, {
    required String spaceId,
    required String handoffId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PrivateResultsScreen(spaceId: spaceId, handoffId: handoffId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposalsAsync = ref.watch(pendingProposalsProvider(spaceId));

    return Scaffold(
      backgroundColor: AgoraColors.surfaceDim,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 18, color: AgoraColors.navy),
            const SizedBox(width: AgoraSpacing.xs),
            const Text('Private AI Proposals'),
          ],
        ),
        backgroundColor: AgoraColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Privacy Guarantee Notice
          Container(
            padding: const EdgeInsets.all(AgoraSpacing.md),
            color: AgoraColors.surface,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: AgoraColors.navy,
                ),
                const SizedBox(width: AgoraSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Private to you · Zero Board mutation',
                        style: AgoraTypography.titleMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'These items are strictly non-authoritative proposals. No tasks, decisions, or questions have been created on the shared Board or shared with other members.',
                        style: AgoraTypography.bodySmall.copyWith(
                          color: AgoraColors.navyDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: proposalsAsync.when(
              loading: () => const AgoraLoadingIndicator(
                message: 'Loading private proposals...',
              ),
              error: (err, _) => AgoraErrorView(
                title: 'Unable to load proposals',
                message: err.toString(),
                onRetry: () =>
                    ref.invalidate(pendingProposalsProvider(spaceId)),
              ),
              data: (proposals) {
                // Filter to this handoff if handoffId is provided
                final filtered = proposals
                    .where((p) => p.handoffId == handoffId)
                    .toList();
                final displayList = filtered.isNotEmpty ? filtered : proposals;

                if (displayList.isEmpty) {
                  return const AgoraEmptyState(
                    icon: Icons.auto_awesome,
                    title: 'No Proposals Generated',
                    message: 'The model extracted no structured tasks, decisions, or questions from the handed-off messages.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AgoraSpacing.lg),
                  itemCount: displayList.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AgoraSpacing.md),
                  itemBuilder: (context, index) {
                    final proposal = displayList[index];
                    return _PrivateProposalCard(proposal: proposal);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateProposalCard extends StatelessWidget {
  const _PrivateProposalCard({required this.proposal});

  final Proposal proposal;

  @override
  Widget build(BuildContext context) {
    AgoraBadgeVariant badgeVariant;
    String badgeLabel;

    switch (proposal.type) {
      case ItemType.task:
        badgeVariant = AgoraBadgeVariant.aegean;
        badgeLabel = 'TASK PROPOSAL';
        break;
      case ItemType.decision:
        badgeVariant = AgoraBadgeVariant.success;
        badgeLabel = 'DECISION PROPOSAL';
        break;
      case ItemType.question:
        badgeVariant = AgoraBadgeVariant.warning;
        badgeLabel = 'QUESTION PROPOSAL';
        break;
    }

    final isFixture = proposal.payload['provider'] == 'fixture';

    return AgoraCard(
      padding: const EdgeInsets.all(AgoraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AgoraBadge(label: badgeLabel, variant: badgeVariant),
              const SizedBox(width: AgoraSpacing.xs),
              const AgoraAiBadge(label: 'PRIVATE PROPOSAL'),
              const Spacer(),
              if (isFixture)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AgoraColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AgoraColors.surfaceBorder),
                  ),
                  child: Text(
                    'Demo fixture',
                    style: AgoraTypography.labelSmall.copyWith(
                      color: AgoraColors.navySubtle,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AgoraSpacing.sm),

          Text(
            proposal.title,
            style: AgoraTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          if (proposal.payload['description'] != null &&
              proposal.payload['description'].toString().isNotEmpty) ...[
            const SizedBox(height: AgoraSpacing.xs),
            Text(
              proposal.payload['description'].toString(),
              style: AgoraTypography.bodyMedium,
            ),
          ],

          const SizedBox(height: AgoraSpacing.md),

          // Provenance details
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AgoraSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AgoraColors.goldContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AgoraColors.goldContainerBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link, size: 14, color: AgoraColors.goldDark),
                const SizedBox(width: AgoraSpacing.xs),
                Text(
                  'Anchored to ${proposal.sourceMessageIds.length} source messages',
                  style: AgoraTypography.labelSmall.copyWith(
                    color: AgoraColors.goldDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
