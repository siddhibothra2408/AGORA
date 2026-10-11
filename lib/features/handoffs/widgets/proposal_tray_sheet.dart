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
import '../../items/models/item.dart';
import '../models/proposal.dart';
import '../repositories/handoff_repository.dart';

/// Modal sheet for reviewing pending AI proposals for a Space.
///
/// Implements the non-authoritative thesis:
/// AI outputs remain strictly in this tray until a human explicitly approves, edits,
/// or dismisses each proposal. Nothing enters the Board without human action.
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
  final Map<String, TextEditingController> _titleControllers = {};
  final Map<String, DateTime?> _dueDateOverrides = {};
  String? _busyProposalId;

  @override
  void dispose() {
    for (final c in _titleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(Proposal p) {
    return _titleControllers.putIfAbsent(
      p.id,
      () => TextEditingController(text: p.title),
    );
  }

  Future<void> _handleApprove(Proposal proposal) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() => _busyProposalId = proposal.id);
    try {
      final editedTitle = _titleControllers[proposal.id]?.text.trim();
      final editedDueDate = _dueDateOverrides[proposal.id];

      await ref
          .read(handoffRepositoryProvider)
          .approveProposal(
            spaceId: widget.spaceId,
            proposal: proposal,
            approvedByUid: uid,
            editedTitle: (editedTitle != null && editedTitle.isNotEmpty)
                ? editedTitle
                : null,
            editedDueDate: editedDueDate,
            assignedTo: proposal.payload['suggestedAssigneeUid'] as String?,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approved "${proposal.title}" as human action item.'),
            backgroundColor: AgoraColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve proposal: $e'),
            backgroundColor: AgoraColors.error,
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
            content: Text('Failed to dismiss: $e'),
            backgroundColor: AgoraColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyProposalId = null);
    }
  }

  Future<void> _pickDueDate(Proposal proposal) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _dueDateOverrides[proposal.id] ?? now.add(const Duration(days: 3)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDateOverrides[proposal.id] = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proposalsAsync = ref.watch(pendingProposalsProvider(widget.spaceId));

    return Container(
      decoration: const BoxDecoration(
        color: AgoraColors.surfaceDim,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AgoraRadius.lg),
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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

          // Header
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
                        'Strictly non-authoritative · Requires human approval',
                        style: AgoraTypography.bodySmall.copyWith(
                          color: AgoraColors.navySubtle,
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

          // Content
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

                return ListView.separated(
                  padding: const EdgeInsets.all(AgoraSpacing.lg),
                  itemCount: proposals.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AgoraSpacing.md),
                  itemBuilder: (context, index) {
                    final proposal = proposals[index];
                    final isBusy = _busyProposalId == proposal.id;
                    final quote = proposal.payload['quote'] as String? ?? '';
                    final suggestedAssignee =
                        proposal.payload['suggestedAssigneeName'] as String?;
                    final controller = _getController(proposal);
                    final effectiveDueDate =
                        _dueDateOverrides[proposal.id] ??
                        (proposal.payload['dueDate'] != null
                            ? DateTime.tryParse(
                                proposal.payload['dueDate'].toString(),
                              )
                            : null);

                    return AgoraCard(
                      padding: const EdgeInsets.all(AgoraSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge Row
                          Row(
                            children: [
                              AgoraAiBadge(
                                label: switch (proposal.type) {
                                  ItemType.task => 'TASK PROPOSAL',
                                  ItemType.decision => 'DECISION PROPOSAL',
                                  ItemType.question => 'QUESTION PROPOSAL',
                                },
                              ),
                              const Spacer(),
                              Text(
                                'Pending Review',
                                style: AgoraTypography.labelSmall.copyWith(
                                  color: AgoraColors.navyMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AgoraSpacing.sm),

                          // Editable Title field
                          TextField(
                            controller: controller,
                            style: AgoraTypography.titleMedium,
                            decoration: const InputDecoration(
                              labelText: 'Proposal Title (Editable)',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: AgoraSpacing.sm,
                                vertical: AgoraSpacing.xs,
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AgoraSpacing.xs),

                          // Quote Anchor (provenance citation)
                          if (quote.isNotEmpty) ...[
                            Container(
                              margin: const EdgeInsets.only(
                                top: AgoraSpacing.xs,
                              ),
                              padding: const EdgeInsets.all(AgoraSpacing.sm),
                              decoration: BoxDecoration(
                                color: AgoraColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(4),
                                border: const Border(
                                  left: BorderSide(
                                    color: AgoraColors.gold,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.format_quote,
                                    size: 14,
                                    color: AgoraColors.goldDark,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '"$quote"',
                                      style: AgoraTypography.bodySmall.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: AgoraColors.navyDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Due date / Assignee row
                          const SizedBox(height: AgoraSpacing.sm),
                          Wrap(
                            spacing: AgoraSpacing.sm,
                            runSpacing: AgoraSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (proposal.type == ItemType.task) ...[
                                InkWell(
                                  onTap: isBusy
                                      ? null
                                      : () => _pickDueDate(proposal),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AgoraColors.surfaceContainer,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AgoraColors.surfaceBorder,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 13,
                                          color: AgoraColors.aegean,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          effectiveDueDate != null
                                              ? 'Due: ${DateFormat('MMM d, yyyy').format(effectiveDueDate)} (edit)'
                                              : 'Set due date',
                                          style: AgoraTypography.labelSmall
                                              .copyWith(
                                                color: AgoraColors.aegeanDark,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              if (suggestedAssignee != null &&
                                  suggestedAssignee.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AgoraColors.surfaceContainer,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AgoraColors.surfaceBorder,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.person_outline,
                                        size: 13,
                                        color: AgoraColors.navySubtle,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Assign to: $suggestedAssignee',
                                        style: AgoraTypography.labelSmall
                                            .copyWith(
                                              color: AgoraColors.navyDark,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: AgoraSpacing.md),

                          // Actions: Accept / Dismiss
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: isBusy
                                    ? null
                                    : () => _handleDismiss(proposal),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Dismiss'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AgoraColors.navyMuted,
                                ),
                              ),
                              const SizedBox(width: AgoraSpacing.sm),
                              AgoraButton(
                                label: 'Approve to Board',
                                icon: Icons.check,
                                isLoading: isBusy,
                                onPressed: () => _handleApprove(proposal),
                              ),
                            ],
                          ),
                        ],
                      ),
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
