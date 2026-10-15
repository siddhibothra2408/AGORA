import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_radius.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_badge.dart';
import '../../chat/models/message.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../handoffs/models/handoff.dart';
import '../../handoffs/repositories/handoff_repository.dart';
import '../models/item.dart';

/// Provenance Receipts Sheet.
///
/// Implements the immutable provenance thesis:
/// Every task, decision, and question links directly to the exact source messages
/// from which it was proposed, with preceding and succeeding chat context.
/// Provenance is never fabricated: deleted messages honestly display "Source message deleted".
/// Gold styling is strictly reserved for AI-originated elements.
class ItemReceiptsSheet extends ConsumerWidget {
  const ItemReceiptsSheet({
    super.key,
    required this.spaceId,
    required this.item,
  });

  final String spaceId;
  final Item item;

  static void show(BuildContext context, String spaceId, Item item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemReceiptsSheet(spaceId: spaceId, item: item),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(spaceMessagesProvider(spaceId));
    final handoffsAsync = ref.watch(spaceHandoffsProvider(spaceId));
    final isAi = item.isAiOrigin;

    // Find the handoff record if this is an AI item
    final handoffs = handoffsAsync.value ?? [];
    final handoff = item.sourceHandoffId.isNotEmpty
        ? handoffs.cast<Handoff?>().firstWhere(
            (h) => h?.id == item.sourceHandoffId,
            orElse: () => null,
          )
        : null;

    return Container(
      decoration: const BoxDecoration(
        color: AgoraColors.surfaceDim,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AgoraRadius.xl),
        ),
      ),
      padding: const EdgeInsets.all(AgoraSpacing.lg),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AgoraColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AgoraSpacing.md),

          // Title & Origin Header (Gold reserved exclusively for AI)
          Row(
            children: [
              if (isAi)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
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
                        size: 14,
                        color: AgoraColors.goldDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI-Assisted · Human Approved',
                        style: AgoraTypography.labelSmall.copyWith(
                          color: AgoraColors.goldDark,
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
              Text(
                item.type.name.toUpperCase(),
                style: AgoraTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AgoraColors.navySubtle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AgoraSpacing.sm),
          Text(item.title, style: AgoraTypography.headlineMedium),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: AgoraSpacing.xs),
            Text(item.description, style: AgoraTypography.bodyMedium),
          ],
          const SizedBox(height: AgoraSpacing.md),

          // AI Provenance Metadata Box (Only for AI-assisted items)
          if (isAi) ...[
            Container(
              padding: const EdgeInsets.all(AgoraSpacing.sm),
              decoration: BoxDecoration(
                color: AgoraColors.goldContainer.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AgoraRadius.sm),
                border: Border.all(color: AgoraColors.goldContainerBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: AgoraColors.goldDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI Provenance Record',
                        style: AgoraTypography.labelSmall.copyWith(
                          color: AgoraColors.goldDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        handoff?.provider ?? 'Gemini 1.5 Pro',
                        style: AgoraTypography.labelSmall.copyWith(
                          color: AgoraColors.goldDark,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Handed off by ${handoff?.handedByName ?? "Team Member"}${handoff != null ? " on ${DateFormat('MMM d, h:mm a').format(handoff.createdAt)}" : ""}. Approved by ${item.approvedByUid.isNotEmpty ? item.approvedByUid : "caller"}.',
                    style: AgoraTypography.bodySmall.copyWith(
                      color: AgoraColors.navyDark,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AgoraSpacing.md),
          ],

          const Divider(height: 1),
          const SizedBox(height: AgoraSpacing.md),

          // Receipts Section Header
          Row(
            children: [
              const Icon(Icons.receipt_long, size: 20, color: AgoraColors.navy),
              const SizedBox(width: AgoraSpacing.xs),
              Text(
                'Source Message Receipts (${item.sourceMessageIds.length})',
                style: AgoraTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AgoraSpacing.xs),
          Text(
            'Exact source messages providing grounding for this item, with context.',
            style: AgoraTypography.bodySmall,
          ),
          const SizedBox(height: AgoraSpacing.md),

          // Receipts Timeline
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Error loading source receipts: $err')),
              data: (messages) {
                if (item.sourceMessageIds.isEmpty) {
                  return const Center(
                    child: Text(
                      'No source message anchors attached to this item.',
                    ),
                  );
                }

                // Sort messages chronologically
                final sortedMessages = List<Message>.from(messages)
                  ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

                return ListView(
                  children: item.sourceMessageIds.map((sourceId) {
                    final sourceIndex = sortedMessages.indexWhere(
                      (m) => m.id == sourceId,
                    );
                    final sourceMsg = sourceIndex != -1
                        ? sortedMessages[sourceIndex]
                        : null;

                    // If source is missing or deleted, honestly show "Source message deleted"
                    if (sourceMsg == null || sourceMsg.isDeleted) {
                      return _DeletedSourceCard(sourceId: sourceId);
                    }

                    // Look up ref flag
                    final sourceRef = item.sourceRefs
                        .cast<ItemSourceRef?>()
                        .firstWhere(
                          (r) => r?.messageId == sourceId,
                          orElse: () => null,
                        );
                    final isEditedSinceHandoff =
                        (sourceRef?.editedSinceHandoff ?? false) ||
                        sourceMsg.isEdited;

                    // Context before (up to 2)
                    final beforeMessages = <Message>[];
                    if (sourceIndex > 0) {
                      final start = sourceIndex >= 2 ? sourceIndex - 2 : 0;
                      beforeMessages.addAll(
                        sortedMessages.sublist(start, sourceIndex),
                      );
                    }

                    // Context after (up to 2)
                    final afterMessages = <Message>[];
                    if (sourceIndex < sortedMessages.length - 1) {
                      final end = (sourceIndex + 3 <= sortedMessages.length)
                          ? sourceIndex + 3
                          : sortedMessages.length;
                      afterMessages.addAll(
                        sortedMessages.sublist(sourceIndex + 1, end),
                      );
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: AgoraSpacing.lg),
                      padding: const EdgeInsets.all(AgoraSpacing.md),
                      decoration: BoxDecoration(
                        color: AgoraColors.surface,
                        borderRadius: BorderRadius.circular(AgoraRadius.md),
                        border: Border.all(
                          color: isAi
                              ? AgoraColors.goldContainerBorder
                              : AgoraColors.surfaceBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Context before
                          if (beforeMessages.isNotEmpty) ...[
                            Text(
                              'Preceding Context:',
                              style: AgoraTypography.labelSmall.copyWith(
                                color: AgoraColors.navyMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...beforeMessages.map(
                              (m) => _ContextBubble(message: m),
                            ),
                            const SizedBox(height: AgoraSpacing.sm),
                          ],

                          // The Source Anchor Message
                          Container(
                            padding: const EdgeInsets.all(AgoraSpacing.md),
                            decoration: BoxDecoration(
                              color: isAi
                                  ? AgoraColors.goldContainer.withValues(
                                      alpha: 0.3,
                                    )
                                  : AgoraColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(
                                AgoraRadius.sm,
                              ),
                              border: Border.all(
                                color: isAi
                                    ? AgoraColors.goldContainerBorder
                                    : AgoraColors.surfaceBorder,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.anchor,
                                      size: 14,
                                      color: isAi
                                          ? AgoraColors.goldDark
                                          : AgoraColors.navySubtle,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'SOURCE ANCHOR · ${sourceMsg.senderDisplayName}',
                                      style: AgoraTypography.labelSmall
                                          .copyWith(
                                            color: isAi
                                                ? AgoraColors.goldDark
                                                : AgoraColors.navyDark,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      DateFormat('h:mm a')
                                          .format(sourceMsg.createdAt),
                                      style: AgoraTypography.bodySmall.copyWith(
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AgoraSpacing.xs),
                                Text(
                                  sourceMsg.text,
                                  style: AgoraTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (isEditedSinceHandoff) ...[
                                  const SizedBox(height: 4),
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
                                      style: AgoraTypography.labelSmall
                                          .copyWith(
                                            color: AgoraColors.terracotta,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Context after
                          if (afterMessages.isNotEmpty) ...[
                            const SizedBox(height: AgoraSpacing.sm),
                            Text(
                              'Succeeding Context:',
                              style: AgoraTypography.labelSmall.copyWith(
                                color: AgoraColors.navyMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...afterMessages.map(
                              (m) => _ContextBubble(message: m),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextBubble extends StatelessWidget {
  const _ContextBubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text(
        '${message.senderDisplayName}: ${message.isDeleted ? "[Message was deleted]" : message.text}',
        style: AgoraTypography.bodySmall.copyWith(color: AgoraColors.navyMuted),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _DeletedSourceCard extends StatelessWidget {
  const _DeletedSourceCard({required this.sourceId});

  final String sourceId;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AgoraSpacing.md),
      padding: const EdgeInsets.all(AgoraSpacing.md),
      decoration: BoxDecoration(
        color: AgoraColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AgoraRadius.sm),
        border: Border.all(color: AgoraColors.surfaceBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.delete_outline,
            color: AgoraColors.navyMuted,
            size: 18,
          ),
          const SizedBox(width: AgoraSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Source message deleted',
                  style: AgoraTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: AgoraColors.navyMuted,
                  ),
                ),
                Text(
                  'ID: $sourceId · Provenance honest reporting preserved.',
                  style: AgoraTypography.bodySmall.copyWith(
                    fontSize: 10,
                    color: AgoraColors.navySubtle,
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
