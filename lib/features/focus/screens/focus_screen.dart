import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_badge.dart';
import '../../../shared/design_system/agora_card.dart';

class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: ListView(
        padding: const EdgeInsets.all(AgoraSpacing.lg),
        children: [
          AgoraCard(
            padding: const EdgeInsets.all(AgoraSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    Text(
                      'Intentional Focus Queue',
                      style: AgoraTypography.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AgoraSpacing.sm),
                Text(
                  'Focus consolidates your human-approved Tasks and Decisions across all your Spaces into an unhurried, calm stream.',
                  style: AgoraTypography.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AgoraSpacing.lg),
          Text(
            'Your Assigned Action Items',
            style: AgoraTypography.headlineMedium,
          ),
          const SizedBox(height: AgoraSpacing.sm),
          AgoraCard(
            padding: const EdgeInsets.all(AgoraSpacing.xl),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 40,
                    color: AgoraColors.success,
                  ),
                  const SizedBox(height: AgoraSpacing.md),
                  Text(
                    'No Pending Action Items',
                    style: AgoraTypography.titleMedium,
                  ),
                  const SizedBox(height: AgoraSpacing.xs),
                  Text(
                    'When tasks are approved on a Space Board and assigned to you, they will appear in your Focus queue.',
                    style: AgoraTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AgoraSpacing.lg),
          Text('Decision Record Queue', style: AgoraTypography.headlineMedium),
          const SizedBox(height: AgoraSpacing.sm),
          AgoraCard(
            padding: const EdgeInsets.all(AgoraSpacing.xl),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.gavel_outlined,
                    size: 40,
                    color: AgoraColors.navySubtle,
                  ),
                  const SizedBox(height: AgoraSpacing.md),
                  Text(
                    'No Decisions Awaiting Input',
                    style: AgoraTypography.titleMedium,
                  ),
                  const SizedBox(height: AgoraSpacing.xs),
                  Text(
                    'Decisions established within your active Spaces will be summarized here with explicit message provenance.',
                    style: AgoraTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
