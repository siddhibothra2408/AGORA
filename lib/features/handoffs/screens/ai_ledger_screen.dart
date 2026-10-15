import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_radius.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_card.dart';
import '../../../shared/design_system/agora_states.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../items/repositories/item_repository.dart';
import '../../items/widgets/item_receipts_sheet.dart';
import '../models/handoff.dart';
import '../repositories/handoff_repository.dart';

/// AI Handoff Ledger Screen.
///
/// Implements the public auditability thesis:
/// Everyone in the Space can see what was handed to the AI, by whom, and when.
/// Text of messages is never duplicated into audit docs; instead, audit records
/// maintain message ID references and live chat storage is queried.
/// Gold styling is strictly reserved for AI-related elements.
class AiLedgerScreen extends ConsumerWidget {
  const AiLedgerScreen({super.key, required this.spaceId});

  final String spaceId;

  static void show(BuildContext context, String spaceId) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AiLedgerScreen(spaceId: spaceId)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handoffsAsync = ref.watch(spaceHandoffsProvider(spaceId));

    return Scaffold(
      backgroundColor: AgoraColors.surfaceDim,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome,
              color: AgoraColors.goldDark,
              size: 20,
            ),
            const SizedBox(width: AgoraSpacing.xs),
            const Text('AI Handoff Ledger'),
          ],
        ),
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
                  Icons.policy_outlined,
                  size: 18,
                  color: AgoraColors.navy,
                ),
                const SizedBox(width: AgoraSpacing.sm),
                Expanded(
                  child: Text(
                    'Immutable audit trail. Every time a member hands messages to AI, the record appears here for all space members.',
                    style: AgoraTypography.bodySmall.copyWith(
                      color: AgoraColors.navyDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: handoffsAsync.when(
              loading: () =>
                  const AgoraLoadingIndicator(message: 'Loading ledger...'),
              error: (err, _) => AgoraErrorView(
                title: 'Unable to load Ledger',
                message: err.toString(),
                onRetry: () => ref.invalidate(spaceHandoffsProvider(spaceId)),
              ),
              data: (handoffs) {
                if (handoffs.isEmpty) {
                  return const AgoraEmptyState(
                    icon: Icons.history_edu_outlined,
                    title: 'No AI Handoffs Yet',
                    message: 'No messages have been handed to AI in this space. Agora operates strictly without ambient AI.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AgoraSpacing.lg),
                  itemCount: handoffs.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AgoraSpacing.md),
                  itemBuilder: (context, index) {
                    final handoff = handoffs[index];
                    return _HandoffLedgerCard(
                      handoff: handoff,
                      onTap: () => _showDetailSheet(context, handoff),
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

  void _showDetailSheet(BuildContext context, Handoff handoff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HandoffDetailSheet(spaceId: spaceId, handoff: handoff),
    );
  }
}

class _HandoffLedgerCard extends StatelessWidget {
  const _HandoffLedgerCard({required this.handoff, required this.onTap});

  final Handoff handoff;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('MMM d, h:mm a').format(handoff.createdAt);
    final isFixture =
        handoff.provider == 'fixture' || handoff.id.contains('fixture');

    return AgoraCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AgoraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AgoraColors.goldContainer,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AgoraColors.goldContainerBorder),
                ),
                child: Text(
                  'HANDOFF',
                  style: AgoraTypography.labelSmall.copyWith(
                    color: AgoraColors.goldDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AgoraSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AgoraColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isFixture ? 'Demo fixture (offline mode)' : handoff.provider,
                  style: AgoraTypography.labelSmall.copyWith(
                    color: AgoraColors.navySubtle,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                timeStr,
                style: AgoraTypography.bodySmall.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: AgoraSpacing.sm),
          Text(
            'Requested by ${handoff.handedByName}',
            style: AgoraTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AgoraSpacing.xs),
          Text(
            'Purpose: ${handoff.promptContext ?? "Extract tasks, decisions, questions"}',
            style: AgoraTypography.bodySmall,
          ),
          const SizedBox(height: AgoraSpacing.md),

          // Counts Wrap
          Wrap(
            spacing: AgoraSpacing.xs,
            runSpacing: AgoraSpacing.xs,
            children: [
              _StatBadge(
                label: '${handoff.messageCount} included',
                color: AgoraColors.aegean,
              ),
              if (handoff.withheldCount > 0)
                _StatBadge(
                  label: '${handoff.withheldCount} withheld',
                  color: AgoraColors.navySubtle,
                ),
              if (handoff.deletedCount > 0)
                _StatBadge(
                  label: '${handoff.deletedCount} deleted',
                  color: AgoraColors.navyMuted,
                ),
              _StatBadge(
                label: '${handoff.proposalCount} proposed',
                color: AgoraColors.goldDark,
              ),
              _StatBadge(
                label: '${handoff.acceptedCount} accepted',
                color: AgoraColors.success,
              ),
              if (handoff.dismissedCount > 0)
                _StatBadge(
                  label: '${handoff.dismissedCount} dismissed',
                  color: AgoraColors.navyMuted,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AgoraTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HandoffDetailSheet extends ConsumerWidget {
  const _HandoffDetailSheet({required this.spaceId, required this.handoff});

  final String spaceId;
  final Handoff handoff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(spaceMessagesProvider(spaceId));
    final itemsAsync = ref.watch(
      spaceItemsProvider((spaceId: spaceId, type: null)),
    );

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
          Row(
            children: [
              Text('Handoff Detail', style: AgoraTypography.headlineMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AgoraColors.goldContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  handoff.status.toUpperCase(),
                  style: AgoraTypography.labelSmall.copyWith(
                    color: AgoraColors.goldDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Handoff ID: ${handoff.id}',
            style: AgoraTypography.bodySmall.copyWith(fontSize: 11),
          ),
          const SizedBox(height: AgoraSpacing.md),

          Expanded(
            child: ListView(
              children: [
                // Audit Dispatched & Integrity Box
                Container(
                  padding: const EdgeInsets.all(AgoraSpacing.md),
                  decoration: BoxDecoration(
                    color: AgoraColors.surface,
                    borderRadius: BorderRadius.circular(AgoraRadius.md),
                    border: Border.all(color: AgoraColors.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audit & Dispatch Verification',
                        style: AgoraTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AgoraColors.navyDark,
                        ),
                      ),
                      const SizedBox(height: AgoraSpacing.xs),
                      Text(
                        'Provider: ${handoff.provider} · Dispatched: ${handoff.auditLog['dispatched'] == true}',
                        style: AgoraTypography.bodySmall,
                      ),
                      Text(
                        'Messages Included: ${handoff.messageCount} · Withheld by consent: ${handoff.withheldCount} · Deleted: ${handoff.deletedCount}',
                        style: AgoraTypography.bodySmall,
                      ),
                      const SizedBox(height: AgoraSpacing.xs),
                      Text(
                        'Agora Guarantee: Message text is never stored in audit docs. Real-time chat storage is verified on read.',
                        style: AgoraTypography.bodySmall.copyWith(
                          color: AgoraColors.aegeanDark,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AgoraSpacing.lg),

                // Live message verification (messages are never duplicated in the handoff doc)
                Text(
                  'Messages Included (${handoff.messageIds.length})',
                  style: AgoraTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AgoraSpacing.xs),
                Text(
                  'Fetched live from chat storage; message text is not duplicated in handoff logs.',
                  style: AgoraTypography.bodySmall,
                ),
                const SizedBox(height: AgoraSpacing.sm),

                messagesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, error) =>
                      const Text('Unable to load message text.'),
                  data: (messages) {
                    final included = messages
                        .where((m) => handoff.messageIds.contains(m.id))
                        .toList();

                    if (included.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(AgoraSpacing.md),
                        decoration: BoxDecoration(
                          color: AgoraColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(AgoraRadius.sm),
                        ),
                        child: Text(
                          'Source messages unavailable or deleted.',
                          style: AgoraTypography.bodySmall.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: included.map((m) {
                        return Container(
                          margin: const EdgeInsets.only(
                            bottom: AgoraSpacing.xs,
                          ),
                          padding: const EdgeInsets.all(AgoraSpacing.sm),
                          decoration: BoxDecoration(
                            color: AgoraColors.surface,
                            borderRadius: BorderRadius.circular(AgoraRadius.sm),
                            border: Border.all(
                              color: AgoraColors.surfaceBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    m.senderDisplayName,
                                    style: AgoraTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: AgoraSpacing.xs),
                                  Text(
                                    DateFormat('h:mm a').format(m.createdAt),
                                    style: AgoraTypography.bodySmall.copyWith(
                                      fontSize: 10,
                                      color: AgoraColors.navySubtle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                m.isDeleted
                                    ? '[Message was deleted by author]'
                                    : m.text,
                                style: AgoraTypography.bodySmall.copyWith(
                                  fontStyle: m.isDeleted
                                      ? FontStyle.italic
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: AgoraSpacing.lg),

                // Approved Items from this Handoff
                Text(
                  'Items Promoted to Board (${handoff.acceptedCount})',
                  style: AgoraTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AgoraSpacing.xs),

                itemsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, error) => const SizedBox.shrink(),
                  data: (items) {
                    final fromHandoff = items
                        .where((i) => i.sourceHandoffId == handoff.id)
                        .toList();

                    if (fromHandoff.isEmpty) {
                      return Text(
                        'No items approved into the Board from this handoff yet.',
                        style: AgoraTypography.bodySmall.copyWith(
                          color: AgoraColors.navySubtle,
                        ),
                      );
                    }

                    return Column(
                      children: fromHandoff.map((i) {
                        return InkWell(
                          onTap: () =>
                              ItemReceiptsSheet.show(context, spaceId, i),
                          child: Container(
                            margin: const EdgeInsets.only(
                              bottom: AgoraSpacing.xs,
                            ),
                            padding: const EdgeInsets.all(AgoraSpacing.sm),
                            decoration: BoxDecoration(
                              color: AgoraColors.surface,
                              borderRadius: BorderRadius.circular(
                                AgoraRadius.sm,
                              ),
                              border: Border.all(
                                color: AgoraColors.goldContainerBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: AgoraColors.success,
                                  size: 16,
                                ),
                                const SizedBox(width: AgoraSpacing.sm),
                                Expanded(
                                  child: Text(
                                    i.title,
                                    style: AgoraTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: AgoraColors.navySubtle,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
