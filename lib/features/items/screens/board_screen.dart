import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_radius.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_badge.dart';
import '../../../shared/design_system/agora_button.dart';
import '../../../shared/design_system/agora_card.dart';
import '../../../shared/design_system/agora_states.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../handoffs/repositories/handoff_repository.dart';
import '../../spaces/models/catch_up_summary.dart';
import '../../spaces/repositories/space_repository.dart';
import '../../spaces/widgets/catch_up_card.dart';
import '../models/item.dart';
import '../repositories/item_repository.dart';
import '../widgets/item_receipts_sheet.dart';

/// Board Tab Screen.
///
/// Implements the human ratification thesis:
/// Items here are human-approved Tasks, Decisions, and Questions created manually
/// or promoted from AI proposals. AI NEVER writes items directly.
/// Gold is reserved strictly for AI-related elements (AI origin chips).
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

  void _showManualCreateSheet(BuildContext context) {
    ManualCreateItemSheet.show(context, spaceId: widget.spaceId);
  }

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
    final membersAsync = ref.watch(spaceMembersProvider(widget.spaceId));
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

    final members = membersAsync.value ?? [];

    return Scaffold(
      backgroundColor: AgoraColors.surfaceDim,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AgoraColors.aegean,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('New Item'),
        onPressed: () => _showManualCreateSheet(context),
      ),
      body: Column(
        children: [
          // Catch-Up Card (Deterministic, Blue not Gold, Dismissible)
          if (catchUpSummary != null && catchUpSummary.shouldDisplay)
            CatchUpCard(
              spaceId: widget.spaceId,
              summary: catchUpSummary,
              onDismiss: () => setState(() => _catchUpDismissed = true),
            ),

          // Segmented Filter Strip (Tasks / Decisions / Questions / All)
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
                    onTap: () =>
                        setState(() => _selectedFilter = ItemType.task),
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
              loading: () => const AgoraLoadingIndicator(
                message: 'Loading Board items...',
              ),
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
                    final approver = members.cast<dynamic>().firstWhere(
                      (m) => m.uid == item.approvedByUid,
                      orElse: () => null,
                    );
                    final approverName =
                        approver?.displayName ??
                        (item.approvedByUid.isNotEmpty
                            ? item.approvedByUid
                            : 'team member');

                    final owner = members.cast<dynamic>().firstWhere(
                      (m) => m.uid == item.effectiveOwnerUid,
                      orElse: () => null,
                    );
                    final ownerName = owner?.displayName;

                    return _BoardItemCard(
                      spaceId: widget.spaceId,
                      item: item,
                      approverName: approverName,
                      ownerName: ownerName,
                      currentUid: currentUid,
                      onStatusChanged: (newStatus) {
                        ref
                            .read(itemRepositoryProvider)
                            .updateItemStatus(
                              widget.spaceId,
                              item.id,
                              newStatus,
                            );
                      },
                      onAssignmentResponse: (accepted) {
                        ref
                            .read(itemRepositoryProvider)
                            .updateAssignmentStatus(
                              widget.spaceId,
                              item.id,
                              accepted
                                  ? AssignmentStatus.accepted
                                  : AssignmentStatus.declined,
                            );
                      },
                    );
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

class _BoardItemCard extends StatelessWidget {
  const _BoardItemCard({
    required this.spaceId,
    required this.item,
    required this.approverName,
    required this.ownerName,
    required this.currentUid,
    required this.onStatusChanged,
    required this.onAssignmentResponse,
  });

  final String spaceId;
  final Item item;
  final String approverName;
  final String? ownerName;
  final String currentUid;
  final ValueChanged<ItemStatus> onStatusChanged;
  final ValueChanged<bool> onAssignmentResponse;

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
    final isDropped = item.status == ItemStatus.dismissed;
    final isAi = item.isAiOrigin;
    final isProposedForMe =
        item.assignmentStatus == AssignmentStatus.proposed &&
        item.effectiveOwnerUid == currentUid;

    return AgoraCard(
      onTap: () => ItemReceiptsSheet.show(context, spaceId, item),
      padding: const EdgeInsets.all(AgoraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Type Badge + Origin Chip (Gold strictly for AI)
          Row(
            children: [
              AgoraBadge(label: badgeLabel, variant: badgeVariant),
              const SizedBox(width: AgoraSpacing.xs),
              if (isAi)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AgoraColors.goldContainer,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AgoraColors.goldContainerBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 11,
                        color: AgoraColors.goldDark,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'AI-assisted · approved by $approverName',
                        style: AgoraTypography.labelSmall.copyWith(
                          color: AgoraColors.goldDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const AgoraBadge(
                  label: 'MANUAL ENTRY',
                  variant: AgoraBadgeVariant.neutral,
                ),
              const Spacer(),

              // Task Checkbox or Status Action Menu
              if (item.isTask)
                Checkbox(
                  value: isDone,
                  activeColor: AgoraColors.aegean,
                  onChanged: (val) {
                    onStatusChanged(
                      val == true ? ItemStatus.completed : ItemStatus.open,
                    );
                  },
                )
              else
                PopupMenuButton<ItemStatus>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 18,
                    color: AgoraColors.navySubtle,
                  ),
                  onSelected: onStatusChanged,
                  itemBuilder: (context) {
                    if (item.isDecision) {
                      return [
                        const PopupMenuItem(
                          value: ItemStatus.completed,
                          child: Text('Supersede Decision'),
                        ),
                        const PopupMenuItem(
                          value: ItemStatus.open,
                          child: Text('Reactivate Decision'),
                        ),
                      ];
                    } else {
                      return [
                        const PopupMenuItem(
                          value: ItemStatus.completed,
                          child: Text('Mark Answered'),
                        ),
                        const PopupMenuItem(
                          value: ItemStatus.open,
                          child: Text('Reopen Question'),
                        ),
                        const PopupMenuItem(
                          value: ItemStatus.dismissed,
                          child: Text('Dismiss Question'),
                        ),
                      ];
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: AgoraSpacing.sm),

          // Title
          Text(
            item.title,
            style: AgoraTypography.titleMedium.copyWith(
              decoration: (isDone || isDropped)
                  ? TextDecoration.lineThrough
                  : null,
              color: (isDone || isDropped)
                  ? AgoraColors.navyDisabled
                  : AgoraColors.navyDark,
              fontWeight: FontWeight.w700,
            ),
          ),

          // Description / Detail
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: AgoraSpacing.xs),
            Text(
              item.description,
              style: AgoraTypography.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Status & Owner & Due Date Wrap
          const SizedBox(height: AgoraSpacing.sm),
          Wrap(
            spacing: AgoraSpacing.xs,
            runSpacing: AgoraSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Owner
              if (ownerName != null)
                Container(
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
                        Icons.person_outline,
                        size: 12,
                        color: AgoraColors.navySubtle,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ownerName!,
                        style: AgoraTypography.labelSmall.copyWith(
                          color: AgoraColors.navyDark,
                        ),
                      ),
                    ],
                  ),
                ),

              // Due Date
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

              // Decision / Question Status Chip
              if (!item.isTask)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AgoraColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.status.name.toUpperCase(),
                    style: AgoraTypography.labelSmall.copyWith(
                      color: AgoraColors.navySubtle,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          // "Proposed for you" Accept / Decline Row
          if (isProposedForMe) ...[
            const SizedBox(height: AgoraSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AgoraSpacing.sm),
              decoration: BoxDecoration(
                color: AgoraColors.aegeanContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AgoraRadius.sm),
                border: Border.all(color: AgoraColors.aegeanContainerBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment_ind_outlined,
                    size: 16,
                    color: AgoraColors.aegeanDark,
                  ),
                  const SizedBox(width: AgoraSpacing.xs),
                  Expanded(
                    child: Text(
                      'Proposed assignment for you',
                      style: AgoraTypography.labelSmall.copyWith(
                        color: AgoraColors.aegeanDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onAssignmentResponse(false),
                    style: TextButton.styleFrom(
                      foregroundColor: AgoraColors.terracotta,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => onAssignmentResponse(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AgoraColors.aegean,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Accept'),
                  ),
                ],
              ),
            ),
          ],

          // Source Anchors Counter (Gold strictly for AI items)
          if (item.sourceMessageIds.isNotEmpty) ...[
            const SizedBox(height: AgoraSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AgoraSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isAi
                    ? AgoraColors.goldContainer
                    : AgoraColors.surfaceContainer,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isAi
                      ? AgoraColors.goldContainerBorder
                      : AgoraColors.surfaceBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.link,
                    size: 14,
                    color: isAi ? AgoraColors.goldDark : AgoraColors.navySubtle,
                  ),
                  const SizedBox(width: AgoraSpacing.xs),
                  Text(
                    'Anchored to ${item.sourceMessageIds.length} source ${item.sourceMessageIds.length == 1 ? 'message' : 'messages'}',
                    style: AgoraTypography.labelSmall.copyWith(
                      color: isAi ? AgoraColors.goldDark : AgoraColors.navyDark,
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

class ManualCreateItemSheet extends ConsumerStatefulWidget {
  const ManualCreateItemSheet({
    super.key,
    required this.spaceId,
    this.initialSourceMessageIds = const [],
  });

  final String spaceId;
  final List<String> initialSourceMessageIds;

  static void show(
    BuildContext context, {
    required String spaceId,
    List<String> initialSourceMessageIds = const [],
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualCreateItemSheet(
        spaceId: spaceId,
        initialSourceMessageIds: initialSourceMessageIds,
      ),
    );
  }

  @override
  ConsumerState<ManualCreateItemSheet> createState() =>
      _ManualCreateItemSheetState();
}

class _ManualCreateItemSheetState extends ConsumerState<ManualCreateItemSheet> {
  final _titleController = TextEditingController();
  final _detailController = TextEditingController();
  ItemType _type = ItemType.task;
  DateTime? _dueDate;
  String? _ownerUid;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 3)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final currentUid = ref.read(currentUserIdProvider) ?? '';
    setState(() => _isSaving = true);

    try {
      final newItem = Item(
        id: '',
        spaceId: widget.spaceId,
        type: _type,
        title: title,
        description: _detailController.text.trim(),
        status: ItemStatus.open,
        origin: 'manual',
        sourceHandoffId: '',
        sourceMessageIds: widget.initialSourceMessageIds,
        approvedByUid: '',
        ownerUid: _ownerUid,
        assigneeUid: _ownerUid,
        dueDate: _dueDate,
        assignmentStatus: (_ownerUid != null && _ownerUid != currentUid)
            ? AssignmentStatus.proposed
            : AssignmentStatus.accepted,
        createdBy: currentUid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(itemRepositoryProvider).createItem(newItem);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created ${_type.name.toUpperCase()}: "$title"'),
            backgroundColor: AgoraColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create item: $e'),
            backgroundColor: AgoraColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(spaceMembersProvider(widget.spaceId));

    return Container(
      decoration: const BoxDecoration(
        color: AgoraColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AgoraRadius.lg),
        ),
      ),
      padding: EdgeInsets.only(
        left: AgoraSpacing.lg,
        right: AgoraSpacing.lg,
        top: AgoraSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AgoraSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Create Manual Item', style: AgoraTypography.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AgoraSpacing.md),

            // Item Type Segmented Control
            Text('Item Type', style: AgoraTypography.labelMedium),
            const SizedBox(height: AgoraSpacing.xs),
            SegmentedButton<ItemType>(
              segments: const [
                ButtonSegment(value: ItemType.task, label: Text('Task')),
                ButtonSegment(
                  value: ItemType.decision,
                  label: Text('Decision'),
                ),
                ButtonSegment(
                  value: ItemType.question,
                  label: Text('Question'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (newVal) {
                setState(() => _type = newVal.first);
              },
            ),
            const SizedBox(height: AgoraSpacing.md),

            // Title
            TextField(
              controller: _titleController,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Title (required)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AgoraSpacing.sm),

            // Detail
            TextField(
              controller: _detailController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Detail / Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AgoraSpacing.sm),

            // Due Date
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDueDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _dueDate != null
                          ? 'Due: ${DateFormat('MMM d, yyyy').format(_dueDate!)}'
                          : 'Set Due Date',
                    ),
                  ),
                ),
                if (_dueDate != null)
                  IconButton(
                    tooltip: 'Clear due date',
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
              ],
            ),
            const SizedBox(height: AgoraSpacing.sm),

            // Owner picker
            membersAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (err, st) => const SizedBox.shrink(),
              data: (members) {
                return DropdownButtonFormField<String?>(
                  initialValue: _ownerUid,
                  decoration: const InputDecoration(
                    labelText: 'Assign Owner',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ...members.map(
                      (m) => DropdownMenuItem<String?>(
                        value: m.uid,
                        child: Text('${m.displayName} (@${m.handle})'),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _ownerUid = val),
                );
              },
            ),

            if (widget.initialSourceMessageIds.isNotEmpty) ...[
              const SizedBox(height: AgoraSpacing.sm),
              Text(
                'Linked to 1 source message from chat',
                style: AgoraTypography.bodySmall.copyWith(
                  color: AgoraColors.navySubtle,
                ),
              ),
            ],

            const SizedBox(height: AgoraSpacing.lg),

            // Create button
            SizedBox(
              width: double.infinity,
              child: AgoraButton(
                label: 'Create Item',
                icon: Icons.check,
                isLoading: _isSaving,
                onPressed: _handleSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
