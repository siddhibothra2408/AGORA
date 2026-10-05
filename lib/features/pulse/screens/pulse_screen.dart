import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_badge.dart';
import '../../../shared/design_system/agora_card.dart';
import '../../../shared/design_system/agora_states.dart';
import '../../handoffs/repositories/handoff_repository.dart';
import '../../spaces/models/ai_consent_state.dart';
import '../../spaces/repositories/space_repository.dart';

class PulseScreen extends ConsumerWidget {
  const PulseScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(spaceMembersProvider(spaceId));
    final handoffsAsync = ref.watch(spaceHandoffsProvider(spaceId));
    final spaceAsync = ref.watch(currentSpaceProvider(spaceId));

    return ListView(
      padding: const EdgeInsets.all(AgoraSpacing.lg),
      children: [
        // Space Governance Overview
        spaceAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (space) => AgoraCard(
            padding: const EdgeInsets.all(AgoraSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.gavel_outlined,
                      size: 20,
                      color: AgoraColors.navy,
                    ),
                    const SizedBox(width: AgoraSpacing.xs),
                    Text(
                      'Space Charter & Consent',
                      style: AgoraTypography.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AgoraSpacing.sm),
                Text(
                  space?.charter.isNotEmpty == true ? space!.charter : 'Standard Agora Consent Charter active. Zero ambient AI monitoring.',
                  style: AgoraTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AgoraSpacing.lg),

        // Member Consent Statistics
        Text('Member Consent Posture', style: AgoraTypography.headlineMedium),
        const SizedBox(height: AgoraSpacing.sm),
        membersAsync.when(
          loading: () => const AgoraLoadingIndicator(),
          error: (err, _) => Text('Error: $err'),
          data: (members) {
            final total = members.length;
            final withheldCount = members
                .where((m) => m.consentState == MemberConsentState.withheld)
                .length;
            final eligibleCount = total - withheldCount;

            return AgoraCard(
              padding: const EdgeInsets.all(AgoraSpacing.lg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(
                        label: 'Total Members',
                        value: '$total',
                        color: AgoraColors.navyDark,
                      ),
                      _StatColumn(
                        label: 'Eligible',
                        value: '$eligibleCount',
                        color: AgoraColors.aegean,
                      ),
                      _StatColumn(
                        label: 'AI Withheld',
                        value: '$withheldCount',
                        color: AgoraColors.withhold,
                      ),
                    ],
                  ),
                  const SizedBox(height: AgoraSpacing.md),
                  const Divider(),
                  const SizedBox(height: AgoraSpacing.sm),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      color: AgoraColors.surfaceBorderSubtle,
                    ),
                    itemBuilder: (context, i) {
                      final m = members[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AgoraColors.aegeanContainer,
                          child: Text(
                            m.displayName.isNotEmpty
                                ? m.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AgoraColors.aegeanDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          m.displayName,
                          style: AgoraTypography.titleMedium,
                        ),
                        subtitle: Text('@${m.handle} · ${m.role.name}'),
                        trailing: AgoraConsentBadge(
                          isWithheld:
                              m.consentState == MemberConsentState.withheld,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: AgoraSpacing.xl),

        // AI Handoff Audit Log (Transparency Invariant)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('AI Handoff Audit', style: AgoraTypography.headlineMedium),
            const AgoraAiBadge(label: 'AUDITABLE'),
          ],
        ),
        const SizedBox(height: AgoraSpacing.xs),
        Text(
          'Every occasion human messages are handed to AI is logged transparently for all space members.',
          style: AgoraTypography.bodySmall,
        ),
        const SizedBox(height: AgoraSpacing.sm),

        handoffsAsync.when(
          loading: () => const AgoraLoadingIndicator(),
          error: (err, _) => Text('Error loading handoffs: $err'),
          data: (handoffs) {
            if (handoffs.isEmpty) {
              return const AgoraCard(
                padding: EdgeInsets.all(AgoraSpacing.lg),
                child: Center(
                  child: Text(
                    'No AI handoffs have occurred in this space yet.\nAI has ingested 0 messages.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: handoffs.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AgoraSpacing.sm),
              itemBuilder: (context, i) {
                final h = handoffs[i];
                final dateStr = DateFormat('MMM d, h:mm a').format(h.createdAt);
                return AgoraCard(
                  borderColor: AgoraColors.goldContainerBorder,
                  backgroundColor: AgoraColors.goldContainer,
                  padding: const EdgeInsets.all(AgoraSpacing.md),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history_edu,
                        color: AgoraColors.goldDark,
                        size: 24,
                      ),
                      const SizedBox(width: AgoraSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${h.handedByName} handed ${h.messageCount} messages to AI',
                              style: AgoraTypography.titleMedium.copyWith(
                                color: AgoraColors.goldDark,
                              ),
                            ),
                            Text(
                              dateStr,
                              style: AgoraTypography.bodySmall.copyWith(
                                color: AgoraColors.goldDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AgoraTypography.displayLarge.copyWith(
            color: color,
            fontSize: 28,
          ),
        ),
        Text(label, style: AgoraTypography.labelSmall),
      ],
    );
  }
}
