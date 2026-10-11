import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_badge.dart';
import '../../../shared/design_system/agora_card.dart';
import '../../../shared/design_system/agora_states.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../handoffs/repositories/handoff_repository.dart';
import '../../spaces/models/catch_up_summary.dart';
import '../../spaces/repositories/space_repository.dart';
import '../../spaces/widgets/catch_up_card.dart';
import '../models/item.dart';
import '../repositories/item_repository.dart';

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  ItemType? _selectedFilter;
  bool _catchUpDismissed = false;
  DateTime? _initialLastReadAt;
  bool _hasCapturedSnapshot = false;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(
      spaceItemsProvider((spaceId: widget.spaceId, type: _selectedFilter)),
    );
    final allItemsAsync = ref.watch(
      spaceItemsProvider((spaceId: widget.spaceId, type: null)),
    );
    final messagesAsync = ref.watch(spaceMessagesProvider(widget.spaceId));
    final handoffsAsync = ref.watch(spaceHandoffsProvider(widget.spaceId));
    final currentUid = ref.watch(currentUserIdProvider) ?? '';
    final memberAsync = ref.watch(
      spaceMemberProvider((spaceId: widget.spaceId, uid: currentUid)),
    );

    // Capture initial lastReadAt snapshot on first load
    if (!_hasCapturedSnapshot && memberAsync.hasValue) {
      _initialLastReadAt = memberAsync.value?.lastReadAt;
      _hasCapturedSnapshot = true;
    }

    // Calculate CatchUpSummary
    CatchUpSummary? catchUpSummary;
    if (!_catchUpDismissed &&
        _hasCapturedSnapshot &&
        _initialLastReadAt != null) {
      catchUpSummary = CatchUpSummary.calculate(
        lastReadAt: _initialLastReadAt,
        messages: messagesAsync.value ?? [],
        items: allItemsAsync.value ?? [],
        handoffs: handoffsAsync.value ?? [],
        currentUserId: currentUid,
      );
    }

    return Column(
      children: [
        // Catch-Up Card (Deterministic, Blue not Gold, Dismissible)
        if (catchUpSummary != null && catchUpSummary.shouldDisplay)
          CatchUpCard(
            spaceId: widget.spaceId,
            summary: catchUpSummary,
            onDismiss: () => setState(() => _catchUpDismissed = true),
          ),
        // Filter Strip
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
                  label: 'All Items',
                  isSelected: _selectedFilter == null,
                  onTap: () => setState(() => _selectedFilter = null),
                ),
                const SizedBox(width: AgoraSpacing.xs),
                _FilterChip(
                  label: 'Tasks',
                  isSelected: _selectedFilter == ItemType.task,
                  onTap: () => setState(() => _selectedFilter = ItemType.task),
                ),
                const SizedBox(width: AgoraSpacing.xs),
                _FilterChip(
                  label: 'Decisions',
                  isSelected: _selectedFilter == ItemType.decision,
                  onTap: () =>
                      setState(() => _selectedFilter = ItemType.decision),
                ),
                const SizedBox(width: AgoraSpacing.xs),
                _FilterChip(
                  label: 'Questions',
                  isSelected: _selectedFilter == ItemType.question,
                  onTap: () =>
                      setState(() => _selectedFilter = ItemType.question),
                ),
              ],
            ),
          ),
        ),

        const Divider(height: 1),

        // Items Content
        Expanded(
          child: itemsAsync.when(
            loading: () =>
                const AgoraLoadingIndicator(message: 'Loading Board items...'),
            error: (err, _) => AgoraErrorView(
              title: 'Could not load board',
              message: err.toString(),
              onRetry: () => ref.invalidate(
                spaceItemsProvider((
                  spaceId: widget.spaceId,
                  type: _selectedFilter,
                )),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const AgoraEmptyState(
                  icon: Icons.dashboard_outlined,
                  title: 'Board is Clean',
                  message: 'Items here are human-approved Tasks, Decisions, and Questions created manually or promoted from AI proposals.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AgoraSpacing.lg),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AgoraSpacing.md),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _BoardItemCard(
                    item: item,
                    onStatusChanged: (newStatus) {
                      ref
                          .read(itemRepositoryProvider)
                          .updateItemStatus(widget.spaceId, item.id, newStatus);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
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

class _BoardItemCard extends StatelessWidget {
  const _BoardItemCard({required this.item, required this.onStatusChanged});

  final Item item;
  final ValueChanged<ItemStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    AgoraBadgeVariant badgeVariant;
    String badgeLabel;

    switch (item.type) {
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

    final isDone = item.status == ItemStatus.completed;

    return AgoraCard(
      padding: const EdgeInsets.all(AgoraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AgoraBadge(label: badgeLabel, variant: badgeVariant),
              const SizedBox(width: AgoraSpacing.xs),
              if (item.sourceHandoffId.isNotEmpty)
                const AgoraAiBadge(label: 'PROVENANCE VERIFIED')
              else
                const AgoraBadge(
                  label: 'MANUAL',
                  variant: AgoraBadgeVariant.neutral,
                ),
              const Spacer(),
              if (item.isTask)
                Checkbox(
                  value: isDone,
                  activeColor: AgoraColors.aegean,
                  onChanged: (val) {
                    onStatusChanged(
                      val == true ? ItemStatus.completed : ItemStatus.open,
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: AgoraSpacing.sm),
          Text(
            item.title,
            style: AgoraTypography.titleMedium.copyWith(
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isDone ? AgoraColors.navyDisabled : AgoraColors.navyDark,
            ),
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: AgoraSpacing.xs),
            Text(item.description, style: AgoraTypography.bodyMedium),
          ],
          if (item.dueDate != null ||
              item.assignmentStatus == AssignmentStatus.proposed) ...[
            const SizedBox(height: AgoraSpacing.sm),
            Wrap(
              spacing: AgoraSpacing.xs,
              children: [
                if (item.dueDate != null) ...[
                  Builder(
                    builder: (context) {
                      final isOverdue =
                          !isDone && item.dueDate!.isBefore(DateTime.now());
                      final dateStr = DateFormat('MMM d').format(item.dueDate!);
                      if (isOverdue) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
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
                                size: 13,
                                color: AgoraColors.terracotta,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'OVERDUE · $dateStr',
                                style: AgoraTypography.labelSmall.copyWith(
                                  color: AgoraColors.terracotta,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AgoraColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AgoraColors.surfaceBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.event_outlined,
                              size: 13,
                              color: AgoraColors.navySubtle,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Due $dateStr',
                              style: AgoraTypography.labelSmall.copyWith(
                                color: AgoraColors.navySubtle,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                if (item.assignmentStatus == AssignmentStatus.proposed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AgoraColors.aegeanContainer,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AgoraColors.aegeanContainerBorder,
                      ),
                    ),
                    child: Text(
                      'PROPOSED ASSIGNMENT',
                      style: AgoraTypography.labelSmall.copyWith(
                        color: AgoraColors.aegeanDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (item.sourceMessageIds.isNotEmpty) ...[
            const SizedBox(height: AgoraSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AgoraSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AgoraColors.goldContainer,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AgoraColors.goldContainerBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link, size: 14, color: AgoraColors.goldDark),
                  const SizedBox(width: AgoraSpacing.xs),
                  Text(
                    'Anchored to ${item.sourceMessageIds.length} source ${item.sourceMessageIds.length == 1 ? 'message' : 'messages'}',
                    style: AgoraTypography.labelSmall.copyWith(
                      color: AgoraColors.goldDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
