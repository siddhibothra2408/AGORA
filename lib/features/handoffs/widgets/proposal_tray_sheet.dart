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
import '../../chat/models/message.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../items/models/item.dart';
import '../../spaces/repositories/space_repository.dart';
import '../models/proposal.dart';
import '../repositories/handoff_repository.dart';

/// Interactive Proposal Tray Sheet.
///
/// Implements the non-authoritative thesis:
/// AI outputs remain strictly in this tray until a human explicitly approves, edits,
/// or dismisses each proposal. Nothing enters the Board without human action.
/// Gold is reserved exclusively for AI elements.
class ProposalTraySheet extends ConsumerStatefulWidget {
  const ProposalTraySheet({super.key, required this.spaceId});

  final String spaceId;

  static void show(BuildContext context, String spaceId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProposalTraySheet(spaceId: spaceId),
    );
  }

  @override
  ConsumerState<ProposalTraySheet> createState() => _ProposalTraySheetState();
}

class _ProposalTraySheetState extends ConsumerState<ProposalTraySheet> {
  String? _busyProposalId;

  String _formatFriendlyError(Object error) {
    final str = error.toString();
    if (str.contains('sources-unavailable')) {
      return 'Cannot approve: All source messages have been deleted. Provenance cannot be verified.';
    }
    if (str.contains('permission-denied')) {
      return 'You must be a current space member and the handoff requester to accept proposals.';
    }
    if (str.contains('failed-precondition')) {
      return 'This proposal is no longer pending or has expired.';
    }
    if (str.contains('DataFailure:')) {
      return str.replaceAll('DataFailure:', '').trim();
    }
    return 'Action failed: $str';
  }

  Future<void> _handleApprove(
    Proposal proposal, {
    String? editedTitle,
    String? editedDetail,
    ItemType? editedType,
    DateTime? editedDueDate,
    String? assignedTo,
  }) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() => _busyProposalId = proposal.id);
    try {
      await ref
          .read(handoffRepositoryProvider)
          .approveProposal(
            spaceId: widget.spaceId,
            proposal: proposal,
            approvedByUid: uid,
            editedTitle: editedTitle,
            editedDetail: editedDetail,
            editedType: editedType,
            editedDueDate: editedDueDate,
            assignedTo: assignedTo,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Accepted "${editedTitle ?? proposal.title}" to Board.',
            ),
            backgroundColor: AgoraColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatFriendlyError(e)),
            backgroundColor: AgoraColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyProposalId = null);
    }
  }

  Future<void> _handleDismiss(Proposal proposal) async {
    setState(() => _busyProposalId = proposal.id);
    try {
      await ref
          .read(handoffRepositoryProvider)
          .dismissProposal(proposalId: proposal.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Proposal dismissed.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatFriendlyError(e)),
            backgroundColor: AgoraColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyProposalId = null);
    }
  }

  void _openEditSheet(Proposal proposal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProposalSheet(
        spaceId: widget.spaceId,
        proposal: proposal,
        onSaveAndAccept:
            (editedTitle, editedDetail, editedType, editedDueDate, assignedTo) {
              Navigator.of(context).pop();
              _handleApprove(
                proposal,
                editedTitle: editedTitle,
                editedDetail: editedDetail,
                editedType: editedType,
                editedDueDate: editedDueDate,
                assignedTo: assignedTo,
              );
            },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proposalsAsync = ref.watch(pendingProposalsProvider(widget.spaceId));
    final messagesAsync = ref.watch(spaceMessagesProvider(widget.spaceId));

    return Container(
      decoration: const BoxDecoration(
        color: AgoraColors.surfaceDim,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AgoraRadius.lg),
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(
                top: AgoraSpacing.sm,
                bottom: AgoraSpacing.xs,
              ),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AgoraColors.navySubtle.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header with AI Gold reserved element
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AgoraSpacing.lg,
              vertical: AgoraSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AgoraColors.goldContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: AgoraColors.goldContainerBorder),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: AgoraColors.goldDark,
                  ),
                ),
                const SizedBox(width: AgoraSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Proposals Tray',
                        style: AgoraTypography.titleLarge,
                      ),
                      Text(
                        'AI-generated · proposal · visible only to you',
                        style: AgoraTypography.bodySmall.copyWith(
                          color: AgoraColors.goldDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Proposals List
          Expanded(
            child: proposalsAsync.when(
              loading: () => const AgoraLoadingIndicator(
                message: 'Loading pending proposals...',
              ),
              error: (err, _) => AgoraErrorView(
                title: 'Unable to load proposals',
                message: err.toString(),
                onRetry: () =>
                    ref.invalidate(pendingProposalsProvider(widget.spaceId)),
              ),
              data: (proposals) {
                if (proposals.isEmpty) {
                  return const AgoraEmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'Proposal Tray is Empty',
                    message: 'No pending AI proposals for this space. When a team member executes a manual handoff, proposals appear here for review.',
                  );
                }

                final messages = messagesAsync.value ?? [];

                return ListView.separated(
                  padding: const EdgeInsets.all(AgoraSpacing.lg),
                  itemCount: proposals.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AgoraSpacing.md),
                  itemBuilder: (context, index) {
                    final proposal = proposals[index];
                    final isBusy = _busyProposalId == proposal.id;

                    return _ProposalCard(
                      proposal: proposal,
                      messages: messages,
                      isBusy: isBusy,
                      onAccept: () => _handleApprove(proposal),
                      onEdit: () => _openEditSheet(proposal),
                      onDismiss: () => _handleDismiss(proposal),
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

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.messages,
    required this.isBusy,
    required this.onAccept,
    required this.onEdit,
    required this.onDismiss,
  });

  final Proposal proposal;
  final List<Message> messages;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onEdit;
  final VoidCallback onDismiss;

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

    final dueDate = proposal.dueDate;
    final suggestedAssignee = proposal.suggestedAssigneeName;
    final confidence = proposal.confidence;
    final detail = proposal.detail;

    return AgoraCard(
      padding: const EdgeInsets.all(AgoraSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Type badge + AI Origin notice
          Row(
            children: [
              AgoraBadge(label: badgeLabel, variant: badgeVariant),
              const SizedBox(width: AgoraSpacing.xs),
              const AgoraAiBadge(label: 'PROPOSAL'),
              const Spacer(),
              if (confidence != null && confidence.isNotEmpty)
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
                  child: Text(
                    confidence.toLowerCase().contains('conf')
                        ? confidence
                        : '$confidence confidence',
                    style: AgoraTypography.labelSmall.copyWith(
                      color: AgoraColors.goldDark,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AgoraSpacing.sm),

          // Title
          Text(
            proposal.title,
            style: AgoraTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          // Detail
          if (detail.isNotEmpty) ...[
            const SizedBox(height: AgoraSpacing.xs),
            Text(detail, style: AgoraTypography.bodyMedium),
          ],

          // Metadata row (Due date, confirm date, assignee)
          if (dueDate != null ||
              proposal.confirmDate ||
              (suggestedAssignee != null && suggestedAssignee.isNotEmpty)) ...[
            const SizedBox(height: AgoraSpacing.sm),
            Wrap(
              spacing: AgoraSpacing.xs,
              runSpacing: AgoraSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (dueDate != null)
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
                          Icons.calendar_today,
                          size: 12,
                          color: AgoraColors.aegean,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Due ${DateFormat('MMM d, yyyy').format(dueDate)}',
                          style: AgoraTypography.labelSmall.copyWith(
                            color: AgoraColors.aegeanDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (proposal.confirmDate)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AgoraColors.goldContainer,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AgoraColors.goldContainerBorder,
                      ),
                    ),
                    child: Text(
                      'Confirm date',
                      style: AgoraTypography.labelSmall.copyWith(
                        color: AgoraColors.goldDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (suggestedAssignee != null && suggestedAssignee.isNotEmpty)
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
                          'Assignee: $suggestedAssignee',
                          style: AgoraTypography.labelSmall.copyWith(
                            color: AgoraColors.navyDark,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: AgoraSpacing.md),

          // Source Quotes (Verified Provenance)
          Text(
            'Source Grounding (${proposal.sourceMessageIds.length})',
            style: AgoraTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AgoraColors.navyMuted,
            ),
          ),
          const SizedBox(height: AgoraSpacing.xs),
          if (proposal.sourceMessageIds.isEmpty && proposal.quote != null)
            _LegacyQuoteBlock(quote: proposal.quote!)
          else
            ...proposal.sourceMessageIds.map((sourceId) {
              final msg = messages.cast<Message?>().firstWhere(
                (m) => m?.id == sourceId,
                orElse: () => null,
              );

              if (msg == null || msg.isDeleted) {
                return Container(
                  margin: const EdgeInsets.only(bottom: AgoraSpacing.xs),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AgoraSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AgoraColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AgoraColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 14,
                        color: AgoraColors.navyMuted,
                      ),
                      const SizedBox(width: AgoraSpacing.xs),
                      Expanded(
                        child: Text(
                          'Source message deleted',
                          style: AgoraTypography.bodySmall.copyWith(
                            fontStyle: FontStyle.italic,
                            color: AgoraColors.navyMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final isEditedSinceHandoff =
                  msg.isEdited ||
                  (msg.editedAt != null &&
                      msg.editedAt!.isAfter(proposal.createdAt));

              return Container(
                margin: const EdgeInsets.only(bottom: AgoraSpacing.xs),
                padding: const EdgeInsets.all(AgoraSpacing.sm),
                decoration: BoxDecoration(
                  color: AgoraColors.goldContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                  border: const Border(
                    left: BorderSide(color: AgoraColors.gold, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          msg.senderDisplayName,
                          style: AgoraTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AgoraColors.navyDark,
                          ),
                        ),
                        const SizedBox(width: AgoraSpacing.xs),
                        Text(
                          DateFormat('h:mm a').format(msg.createdAt),
                          style: AgoraTypography.bodySmall.copyWith(
                            fontSize: 10,
                            color: AgoraColors.navySubtle,
                          ),
                        ),
                        if (isEditedSinceHandoff) ...[
                          const SizedBox(width: AgoraSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AgoraColors.terracottaContainer,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              'edited since handoff',
                              style: AgoraTypography.labelSmall.copyWith(
                                color: AgoraColors.terracotta,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '"${msg.text}"',
                      style: AgoraTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AgoraColors.navyDark,
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: AgoraSpacing.md),

          // Actions Row: Dismiss, Edit, Accept
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: isBusy ? null : onDismiss,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Dismiss'),
                style: TextButton.styleFrom(
                  foregroundColor: AgoraColors.navyMuted,
                ),
              ),
              const SizedBox(width: AgoraSpacing.xs),
              OutlinedButton.icon(
                onPressed: isBusy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AgoraColors.navyDark,
                ),
              ),
              const SizedBox(width: AgoraSpacing.xs),
              AgoraButton(
                label: 'Accept',
                icon: Icons.check,
                isLoading: isBusy,
                onPressed: isBusy ? null : onAccept,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegacyQuoteBlock extends StatelessWidget {
  const _LegacyQuoteBlock({required this.quote});

  final String quote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AgoraSpacing.sm),
      decoration: BoxDecoration(
        color: AgoraColors.goldContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
        border: const Border(
          left: BorderSide(color: AgoraColors.gold, width: 3),
        ),
      ),
      child: Text(
        '"$quote"',
        style: AgoraTypography.bodySmall.copyWith(
          fontStyle: FontStyle.italic,
          color: AgoraColors.navyDark,
        ),
      ),
    );
  }
}

class _EditProposalSheet extends ConsumerStatefulWidget {
  const _EditProposalSheet({
    required this.spaceId,
    required this.proposal,
    required this.onSaveAndAccept,
  });

  final String spaceId;
  final Proposal proposal;
  final void Function(
    String editedTitle,
    String? editedDetail,
    ItemType editedType,
    DateTime? editedDueDate,
    String? assignedTo,
  )
  onSaveAndAccept;

  @override
  ConsumerState<_EditProposalSheet> createState() => _EditProposalSheetState();
}

class _EditProposalSheetState extends ConsumerState<_EditProposalSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _detailController;
  late ItemType _selectedType;
  DateTime? _selectedDueDate;
  String? _selectedOwnerUid;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.proposal.title);
    _detailController = TextEditingController(text: widget.proposal.detail);
    _selectedType = widget.proposal.type;
    _selectedDueDate = widget.proposal.dueDate;
    _selectedOwnerUid = widget.proposal.suggestedAssigneeUid;
  }

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
      initialDate: _selectedDueDate ?? now.add(const Duration(days: 3)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() => _selectedDueDate = picked);
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
                Text('Edit Proposal', style: AgoraTypography.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AgoraSpacing.md),

            // Item Type Selector
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
              selected: {_selectedType},
              onSelectionChanged: (newVal) {
                setState(() => _selectedType = newVal.first);
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
                      _selectedDueDate != null
                          ? 'Due: ${DateFormat('MMM d, yyyy').format(_selectedDueDate!)}'
                          : 'Set Due Date',
                    ),
                  ),
                ),
                if (_selectedDueDate != null)
                  IconButton(
                    tooltip: 'Clear due date',
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _selectedDueDate = null),
                  ),
              ],
            ),
            const SizedBox(height: AgoraSpacing.sm),

            // Owner picker from space members
            membersAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (err, st) => const SizedBox.shrink(),
              data: (members) {
                return DropdownButtonFormField<String?>(
                  initialValue: members.any((m) => m.uid == _selectedOwnerUid)
                      ? _selectedOwnerUid
                      : null,
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
                  onChanged: (val) => setState(() => _selectedOwnerUid = val),
                );
              },
            ),

            const SizedBox(height: AgoraSpacing.lg),

            // Save & Accept button
            SizedBox(
              width: double.infinity,
              child: AgoraButton(
                label: 'Save Changes & Accept to Board',
                icon: Icons.check,
                onPressed: () {
                  final title = _titleController.text.trim();
                  if (title.isEmpty) return;
                  widget.onSaveAndAccept(
                    title,
                    _detailController.text.trim().isEmpty
                        ? null
                        : _detailController.text.trim(),
                    _selectedType,
                    _selectedDueDate,
                    _selectedOwnerUid,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
