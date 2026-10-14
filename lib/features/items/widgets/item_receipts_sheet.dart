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
import '../models/item.dart';

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
    final isAi = item.sourceHandoffId.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AgoraColors.surfaceDim,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AgoraRadius.xl),
        ),
      ),
      padding: const EdgeInsets.all(AgoraSpacing.lg),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

          // Title & Origin Header
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

          const Divider(height: 1),
          const SizedBox(height: AgoraSpacing.md),

          // Provenance Receipts Section
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

                    if (sourceMsg == null) {
                      return _MissingSourceCard(sourceId: sourceId);
                    }

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
                          color: AgoraColors.goldContainerBorder,
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
                              color: AgoraColors.goldContainer.withValues(
                                alpha: 0.3,
                              ),
                              borderRadius: BorderRadius.circular(
                                AgoraRadius.sm,
                              ),
                              border: Border.all(
                                color: AgoraColors.goldContainerBorder,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.anchor,
                                      size: 14,
                                      color: AgoraColors.goldDark,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'SOURCE ANCHOR · ${sourceMsg.senderDisplayName}',
                                      style: AgoraTypography.labelSmall
                                          .copyWith(
                                            color: AgoraColors.goldDark,
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
                                  sourceMsg.isDeleted
                                      ? '[Message was deleted by author]'
                                      : sourceMsg.text,
                                  style: AgoraTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontStyle: sourceMsg.isDeleted
                                        ? FontStyle.italic
                                        : null,
                                  ),
                                ),
                                if (sourceMsg.isEdited) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '(edited since handoff)',
                                    style: AgoraTypography.labelSmall.copyWith(
                                      color: AgoraColors.navySubtle,
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
        '${message.senderDisplayName}: ${message.text}',
        style: AgoraTypography.bodySmall.copyWith(color: AgoraColors.navyMuted),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _MissingSourceCard extends StatelessWidget {
  const _MissingSourceCard({required this.sourceId});

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
            Icons.info_outline,
            color: AgoraColors.navyMuted,
            size: 18,
          ),
          const SizedBox(width: AgoraSpacing.sm),
          Expanded(
            child: Text(
              'Source message ($sourceId) is no longer available.',
              style: AgoraTypography.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
