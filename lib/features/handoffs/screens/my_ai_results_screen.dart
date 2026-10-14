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

class MyAiResultsScreen extends ConsumerStatefulWidget {
  const MyAiResultsScreen({super.key, this.spaceId});

  final String? spaceId;

  static void show(BuildContext context, {String? spaceId}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MyAiResultsScreen(spaceId: spaceId)),
    );
  }

  @override
  ConsumerState<MyAiResultsScreen> createState() => _MyAiResultsScreenState();
}

class _MyAiResultsScreenState extends ConsumerState<MyAiResultsScreen> {
  ItemType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    // If spaceId is provided, watch for that space; otherwise watch all user proposals
    final spaceId = widget.spaceId ?? '';
    final proposalsAsync = ref.watch(pendingProposalsProvider(spaceId));

    return Scaffold(
      backgroundColor: AgoraColors.surfaceDim,
      appBar: AppBar(
        title: const Text('My AI Results'),
        backgroundColor: AgoraColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Informational Banner
          Container(
            padding: const EdgeInsets.all(AgoraSpacing.md),
            color: AgoraColors.surface,
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: AgoraColors.navy,
                ),
                const SizedBox(width: AgoraSpacing.sm),
                Expanded(
                  child: Text(
                    'Private AI outputs generated from your handoffs. Only you can view these proposals until you choose to approve them.',
                    style: AgoraTypography.bodySmall.copyWith(
                      color: AgoraColors.navyDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter bar
          Container(
            color: AgoraColors.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AgoraSpacing.md,
              vertical: AgoraSpacing.xs,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _typeFilter == null,
                    onTap: () => setState(() => _typeFilter = null),
                  ),
                  const SizedBox(width: AgoraSpacing.xs),
                  _FilterChip(
                    label: 'Tasks',
                    isSelected: _typeFilter == ItemType.task,
                    onTap: () => setState(() => _typeFilter = ItemType.task),
                  ),
                  const SizedBox(width: AgoraSpacing.xs),
                  _FilterChip(
                    label: 'Decisions',
                    isSelected: _typeFilter == ItemType.decision,
                    onTap: () =>
                        setState(() => _typeFilter = ItemType.decision),
                  ),
                  const SizedBox(width: AgoraSpacing.xs),
                  _FilterChip(
                    label: 'Questions',
                    isSelected: _typeFilter == ItemType.question,
                    onTap: () =>
                        setState(() => _typeFilter = ItemType.question),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: proposalsAsync.when(
              loading: () => const AgoraLoadingIndicator(
                message: 'Loading your AI results...',
              ),
              error: (err, _) => AgoraErrorView(
                title: 'Unable to load results',
                message: err.toString(),
                onRetry: () =>
                    ref.invalidate(pendingProposalsProvider(spaceId)),
              ),
              data: (proposals) {
                final filtered = _typeFilter == null
                    ? proposals
                    : proposals.where((p) => p.type == _typeFilter).toList();

                if (filtered.isEmpty) {
                  return const AgoraEmptyState(
                    icon: Icons.auto_awesome,
                    title: 'No Proposals Found',
                    message: 'You have no pending AI proposals in this view. Use Lens mode in chat to hand off messages.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AgoraSpacing.lg),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AgoraSpacing.md),
                  itemBuilder: (context, index) {
                    final proposal = filtered[index];
                    return _ProposalResultCard(proposal: proposal);
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        color: isSelected ? AgoraColors.aegean : AgoraColors.navyMuted,
      ),
      selectedColor: AgoraColors.aegeanContainer,
      backgroundColor: AgoraColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? AgoraColors.aegeanContainerBorder
              : AgoraColors.surfaceBorder,
        ),
      ),
    );
  }
}

class _ProposalResultCard extends StatelessWidget {
  const _ProposalResultCard({required this.proposal});

  final Proposal proposal;

  @override
  Widget build(BuildContext context) {
    AgoraBadgeVariant badgeVariant;
    String badgeLabel;

    switch (proposal.type) {
      case ItemType.task:
        badgeVariant = AgoraBadgeVariant.aegean;
        badgeLabel = 'TASK';
        break;
      case ItemType.decision:
        badgeVariant = AgoraBadgeVariant.success;
        badgeLabel = 'DECISION';
        break;
      case ItemType.question:
        badgeVariant = AgoraBadgeVariant.warning;
        badgeLabel = 'QUESTION';
        break;
    }

    return AgoraCard(
      padding: const EdgeInsets.all(AgoraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AgoraBadge(label: badgeLabel, variant: badgeVariant),
              const SizedBox(width: AgoraSpacing.xs),
              const AgoraAiBadge(label: 'PROPOSAL'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AgoraColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PENDING REVIEW',
                  style: AgoraTypography.labelSmall.copyWith(
                    color: AgoraColors.navySubtle,
                    fontWeight: FontWeight.w600,
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
          const SizedBox(height: AgoraSpacing.sm),
          Row(
            children: [
              const Icon(Icons.link, size: 14, color: AgoraColors.goldDark),
              const SizedBox(width: 4),
              Text(
                '${proposal.sourceMessageIds.length} source anchors',
                style: AgoraTypography.labelSmall.copyWith(
                  color: AgoraColors.goldDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
