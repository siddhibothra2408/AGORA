import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_badge.dart';
import '../../../shared/design_system/agora_button.dart';
import '../../../shared/design_system/agora_card.dart';
import '../../../shared/design_system/agora_states.dart';
import '../../handoffs/models/proposal.dart';
import '../../handoffs/repositories/handoff_repository.dart';
import '../../handoffs/widgets/proposal_tray_sheet.dart';
import '../../items/models/item.dart';
import '../../items/repositories/item_repository.dart';
import '../../spaces/models/space.dart';
import '../../spaces/repositories/space_repository.dart';

/// Focus Screen
///
/// Principles:
/// - Real data fan-out across the user's active Spaces (no collection-group queries).
/// - Deterministic (no AI, no gold for task lists).
/// - Overdue tasks highlighted with terracotta color tokens.
/// - "Proposed for you" action queue with Accept/Decline.
/// - Pending proposals count per Space linking directly to the proposal tray.
/// - Honest empty, loading, error, and offline states.
class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(currentUserIdProvider) ?? '';
    final spacesAsync = ref.watch(userSpacesProvider);

    return Scaffold(
      backgroundColor: AgoraColors.surfaceDim,
      appBar: AppBar(
        title: Text('Focus', style: AgoraTypography.headlineLarge),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AgoraSpacing.md),
            child: AgoraBadge(
              label: 'DEEP WORK',
              variant: AgoraBadgeVariant.aegean,
            ),
          ),
        ],
      ),
      body: spacesAsync.when(
        loading: () =>
            const AgoraLoadingIndicator(message: 'Loading Focus queue...'),
        error: (err, _) => AgoraErrorView(
          title: 'Could not load Focus',
          message: err.toString(),
          onRetry: () => ref.invalidate(userSpacesProvider),
        ),
        data: (spaces) {
          if (spaces.isEmpty) {
            return const AgoraEmptyState(
              icon: Icons.center_focus_weak,
              title: 'No Spaces Joined',
              message: 'Join or create a Space to start tracking your assigned tasks and decisions in Focus.',
            );
          }

          return _FocusContent(spaces: spaces, currentUid: currentUid);
        },
      ),
    );
  }
}

class _FocusContent extends ConsumerWidget {
  const _FocusContent({required this.spaces, required this.currentUid});

  final List<Space> spaces;
  final String currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacesById = {for (final s in spaces) s.id: s};

    // Fan-out across spaces (without collection-group queries)
    final allItems = <Item>[];
    final pendingProposalsBySpace = <String, List<Proposal>>{};
    bool anyLoading = false;
    Object? firstError;

    for (final space in spaces) {
      final itemsAsync = ref.watch(
        spaceItemsProvider((spaceId: space.id, type: null)),
      );
      final proposalsAsync = ref.watch(pendingProposalsProvider(space.id));

      if (itemsAsync.isLoading || proposalsAsync.isLoading) {
        anyLoading = true;
      }
      if (itemsAsync.hasError) firstError ??= itemsAsync.error;
      if (proposalsAsync.hasError) firstError ??= proposalsAsync.error;

      if (itemsAsync.hasValue) {
        allItems.addAll(itemsAsync.value!);
      }
      if (proposalsAsync.hasValue && proposalsAsync.value!.isNotEmpty) {
        pendingProposalsBySpace[space.id] = proposalsAsync.value!;
      }
    }

    if (anyLoading && allItems.isEmpty) {
      return const AgoraLoadingIndicator(
        message: 'Syncing your assigned items...',
      );
    }

    if (firstError != null && allItems.isEmpty) {
      return AgoraErrorView(
        title: 'Error reading Focus items',
        message: firstError.toString(),
      );
    }

    // 1. Proposed for you (items where assignmentStatus is proposed)
    final proposedForMe = allItems
        .where(
          (i) =>
              i.isTask &&
              i.status != ItemStatus.completed &&
              i.status != ItemStatus.dismissed &&
              i.effectiveOwnerUid == currentUid &&
              i.assignmentStatus == AssignmentStatus.proposed,
        )
        .toList();

    // 2. My open tasks (ownerUid == me, status open/in_progress, assignment accepted)
    final myOpenTasks = allItems
        .where(
          (i) =>
              i.isTask &&
              i.status != ItemStatus.completed &&
              i.status != ItemStatus.dismissed &&
              i.effectiveOwnerUid == currentUid &&
              i.assignmentStatus != AssignmentStatus.proposed &&
              i.assignmentStatus != AssignmentStatus.declined,
        )
        .toList();

    // Sort by due date (overdue first, ascending dates, then items without due date)
    myOpenTasks.sort((a, b) {
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      if (a.dueDate != null && b.dueDate == null) return -1;
      if (a.dueDate == null && b.dueDate != null) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.all(AgoraSpacing.lg),
      children: [
        // Focus Queue Header Card
        AgoraCard(
          padding: const EdgeInsets.all(AgoraSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AgoraSpacing.xs),
                decoration: const BoxDecoration(
                  color: AgoraColors.aegeanContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.center_focus_strong,
                  color: AgoraColors.aegean,
                  size: 20,
                ),
              ),
              const SizedBox(width: AgoraSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deterministic Focus Stream',
                      style: AgoraTypography.titleMedium,
                    ),
                    Text(
                      'All items are human-approved tasks and decisions. Zero AI ambient intrusion.',
                      style: AgoraTypography.bodySmall.copyWith(
                        color: AgoraColors.navySubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Section: Proposed For You (Actionable assignment proposals)
        if (proposedForMe.isNotEmpty) ...[
          const SizedBox(height: AgoraSpacing.lg),
          Row(
            children: [
              Text('Proposed For You', style: AgoraTypography.headlineMedium),
              const SizedBox(width: AgoraSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AgoraColors.aegean,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${proposedForMe.length}',
                  style: AgoraTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AgoraSpacing.xs),
          Text(
            'Tasks assigned to you by peers or approved from AI handoffs. Accept or decline below:',
            style: AgoraTypography.bodySmall,
          ),
          const SizedBox(height: AgoraSpacing.sm),
          ...proposedForMe.map((item) {
            final spaceName = spacesById[item.spaceId]?.name ?? 'Space';
            return Padding(
              padding: const EdgeInsets.only(bottom: AgoraSpacing.sm),
              child: _ProposedAssignmentCard(
                item: item,
                spaceName: spaceName,
                onAccept: () {
                  ref
                      .read(itemRepositoryProvider)
                      .updateAssignmentStatus(
                        item.spaceId,
                        item.id,
                        AssignmentStatus.accepted,
                      );
                },
                onDecline: () {
                  ref
                      .read(itemRepositoryProvider)
                      .updateAssignmentStatus(
                        item.spaceId,
                        item.id,
                        AssignmentStatus.declined,
                      );
                },
              ),
            );
          }),
        ],

        // Section: My Open Tasks
        const SizedBox(height: AgoraSpacing.lg),
        Row(
          children: [
            Text('My Open Tasks', style: AgoraTypography.headlineMedium),
            const SizedBox(width: AgoraSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AgoraColors.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AgoraColors.surfaceBorder),
              ),
              child: Text(
                '${myOpenTasks.length}',
                style: AgoraTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AgoraColors.navyDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AgoraSpacing.sm),

        if (myOpenTasks.isEmpty)
          AgoraCard(
            padding: const EdgeInsets.all(AgoraSpacing.xl),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 36,
                    color: AgoraColors.success,
                  ),
                  const SizedBox(height: AgoraSpacing.sm),
                  Text(
                    'No Open Tasks Assigned to You',
                    style: AgoraTypography.titleMedium,
                  ),
                  const SizedBox(height: AgoraSpacing.xs),
                  Text(
                    'When tasks are approved on a Space Board and assigned to you, they appear here ordered by due date.',
                    style: AgoraTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...myOpenTasks.map((task) {
            final spaceName = spacesById[task.spaceId]?.name ?? 'Space';
            final isOverdue =
                task.dueDate != null && task.dueDate!.isBefore(now);

            return Padding(
              padding: const EdgeInsets.only(bottom: AgoraSpacing.sm),
              child: _FocusTaskCard(
                task: task,
                spaceName: spaceName,
                isOverdue: isOverdue,
                onStatusChanged: (newStatus) {
                  ref
                      .read(itemRepositoryProvider)
                      .updateItemStatus(task.spaceId, task.id, newStatus);
                },
              ),
            );
          }),

        // Section: Pending Proposals Per Space
        const SizedBox(height: AgoraSpacing.xl),
        Text(
          'Pending AI Proposals by Space',
          style: AgoraTypography.headlineMedium,
        ),
        const SizedBox(height: AgoraSpacing.xs),
        Text(
          'Proposals await human review in the tray before entering any Board.',
          style: AgoraTypography.bodySmall,
        ),
        const SizedBox(height: AgoraSpacing.sm),

        if (pendingProposalsBySpace.isEmpty)
          AgoraCard(
            padding: const EdgeInsets.all(AgoraSpacing.lg),
            child: Row(
              children: [
                const Icon(
                  Icons.done_all,
                  size: 20,
                  color: AgoraColors.navySubtle,
                ),
                const SizedBox(width: AgoraSpacing.sm),
                Expanded(
                  child: Text(
                    'All proposal trays are clear across your spaces.',
                    style: AgoraTypography.bodySmall.copyWith(
                      color: AgoraColors.navySubtle,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...pendingProposalsBySpace.entries.map((entry) {
            final space = spacesById[entry.key];
            final spaceName = space?.name ?? 'Space';
            final count = entry.value.length;

            return Padding(
              padding: const EdgeInsets.only(bottom: AgoraSpacing.sm),
              child: AgoraCard(
                padding: const EdgeInsets.all(AgoraSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AgoraColors.goldContainer,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AgoraColors.goldContainerBorder,
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: AgoraColors.goldDark,
                      ),
                    ),
                    const SizedBox(width: AgoraSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(spaceName, style: AgoraTypography.titleMedium),
                          Text(
                            '$count pending ${count == 1 ? 'proposal' : 'proposals'} awaiting human approval',
                            style: AgoraTypography.bodySmall.copyWith(
                              color: AgoraColors.goldDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AgoraButton(
                      label: 'Review Tray ($count)',
                      icon: Icons.inbox_outlined,
                      onPressed: () =>
                          ProposalTraySheet.show(context, entry.key),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _ProposedAssignmentCard extends StatelessWidget {
  const _ProposedAssignmentCard({
    required this.item,
    required this.spaceName,
    required this.onAccept,
    required this.onDecline,
  });

  final Item item;
  final String spaceName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return AgoraCard(
      padding: const EdgeInsets.all(AgoraSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AgoraColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  spaceName,
                  style: AgoraTypography.labelSmall.copyWith(
                    color: AgoraColors.navySubtle,
                  ),
                ),
              ),
              const SizedBox(width: AgoraSpacing.xs),
              const AgoraBadge(
                label: 'PROPOSED FOR YOU',
                variant: AgoraBadgeVariant.aegean,
              ),
              const Spacer(),
              if (item.sourceHandoffId.isNotEmpty)
                const AgoraAiBadge(label: 'PROVENANCE'),
            ],
          ),
          const SizedBox(height: AgoraSpacing.xs),
          Text(item.title, style: AgoraTypography.titleMedium),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(item.description, style: AgoraTypography.bodySmall),
          ],
          if (item.dueDate != null) ...[
            const SizedBox(height: AgoraSpacing.xs),
            Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 13,
                  color: AgoraColors.navySubtle,
                ),
                const SizedBox(width: 4),
                Text(
                  'Due: ${DateFormat('MMM d').format(item.dueDate!)}',
                  style: AgoraTypography.labelSmall.copyWith(
                    color: AgoraColors.navySubtle,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AgoraSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: onDecline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AgoraColors.navyMuted,
                  side: const BorderSide(color: AgoraColors.surfaceBorder),
                ),
                child: const Text('Decline'),
              ),
              const SizedBox(width: AgoraSpacing.sm),
              AgoraButton(
                label: 'Accept Assignment',
                icon: Icons.check,
                onPressed: onAccept,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FocusTaskCard extends StatelessWidget {
  const _FocusTaskCard({
    required this.task,
    required this.spaceName,
    required this.isOverdue,
    required this.onStatusChanged,
  });

  final Item task;
  final String spaceName;
  final bool isOverdue;
  final ValueChanged<ItemStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return AgoraCard(
      padding: const EdgeInsets.all(AgoraSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: task.status == ItemStatus.completed,
            activeColor: AgoraColors.aegean,
            onChanged: (val) {
              onStatusChanged(
                val == true ? ItemStatus.completed : ItemStatus.open,
              );
            },
          ),
          const SizedBox(width: AgoraSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AgoraColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        spaceName,
                        style: AgoraTypography.labelSmall.copyWith(
                          color: AgoraColors.navySubtle,
                        ),
                      ),
                    ),
                    const SizedBox(width: AgoraSpacing.xs),
                    if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AgoraColors.terracottaContainer,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AgoraColors.terracottaBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 12,
                              color: AgoraColors.terracotta,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'OVERDUE',
                              style: AgoraTypography.labelSmall.copyWith(
                                color: AgoraColors.terracotta,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (task.dueDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AgoraColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AgoraColors.surfaceBorder),
                        ),
                        child: Text(
                          'Due ${DateFormat('MMM d').format(task.dueDate!)}',
                          style: AgoraTypography.labelSmall.copyWith(
                            color: AgoraColors.navySubtle,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (task.sourceHandoffId.isNotEmpty)
                      const AgoraAiBadge(label: 'PROVENANCE'),
                  ],
                ),
                const SizedBox(height: AgoraSpacing.xs),
                Text(
                  task.title,
                  style: AgoraTypography.titleMedium.copyWith(
                    decoration: task.status == ItemStatus.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(task.description, style: AgoraTypography.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
