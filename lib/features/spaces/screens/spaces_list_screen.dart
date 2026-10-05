import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_badge.dart';
import '../../../shared/design_system/agora_button.dart';
import '../../../shared/design_system/agora_card.dart';
import '../../../shared/design_system/agora_states.dart';
import '../models/space.dart';
import '../repositories/space_repository.dart';
import 'create_space_sheet.dart';

class SpacesListScreen extends ConsumerWidget {
  const SpacesListScreen({super.key});

  void _showCreateSpaceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateSpaceSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacesAsync = ref.watch(userSpacesProvider);

    return Scaffold(
      backgroundColor: AgoraColors.surfaceDim,
      appBar: AppBar(
        title: Text('Agora Spaces', style: AgoraTypography.headlineLarge),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AgoraSpacing.md),
            child: AgoraButton(
              label: 'New Space',
              icon: Icons.add,
              onPressed: () => _showCreateSpaceSheet(context),
            ),
          ),
        ],
      ),
      body: spacesAsync.when(
        loading: () =>
            const AgoraLoadingIndicator(message: 'Loading spaces...'),
        error: (err, _) => AgoraErrorView(
          title: 'Could not load spaces',
          message: err.toString(),
          onRetry: () => ref.invalidate(userSpacesProvider),
        ),
        data: (spaces) {
          if (spaces.isEmpty) {
            return AgoraEmptyState(
              icon: Icons.forum_outlined,
              title: 'No Spaces Yet',
              message: 'Spaces are quiet collaboration enclaves with explicit AI consent. Create your first space to get started.',
              actionLabel: 'Create a Space',
              onAction: () => _showCreateSpaceSheet(context),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AgoraSpacing.lg),
            itemCount: spaces.length,
            separatorBuilder: (_, _) => const SizedBox(height: AgoraSpacing.md),
            itemBuilder: (context, index) {
              final space = spaces[index];
              return _SpaceItemCard(space: space);
            },
          );
        },
      ),
    );
  }
}

class _SpaceItemCard extends StatelessWidget {
  const _SpaceItemCard({required this.space});

  final Space space;

  @override
  Widget build(BuildContext context) {
    return AgoraCard(
      onTap: () => context.go('/spaces/${space.id}/chat'),
      padding: const EdgeInsets.all(AgoraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AgoraColors.aegeanContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AgoraColors.aegean,
                  size: 22,
                ),
              ),
              const SizedBox(width: AgoraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(space.name, style: AgoraTypography.titleLarge),
                    const SizedBox(height: AgoraSpacing.xxs),
                    Text(
                      space.description.isNotEmpty
                          ? space.description
                          : 'No description provided',
                      style: AgoraTypography.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AgoraColors.navySubtle,
                size: 20,
              ),
            ],
          ),
          if (space.charter.isNotEmpty) ...[
            const SizedBox(height: AgoraSpacing.md),
            Container(
              padding: const EdgeInsets.all(AgoraSpacing.sm),
              decoration: BoxDecoration(
                color: AgoraColors.surfaceContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AgoraColors.surfaceBorderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.gavel_outlined,
                    size: 14,
                    color: AgoraColors.navyMuted,
                  ),
                  const SizedBox(width: AgoraSpacing.xs),
                  Expanded(
                    child: Text(
                      'Charter: ${space.charter}',
                      style: AgoraTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AgoraSpacing.md),
          Row(
            children: [
              AgoraBadge(
                label:
                    '${space.memberCount} ${space.memberCount == 1 ? 'member' : 'members'}',
                icon: Icons.people_outline,
                variant: AgoraBadgeVariant.neutral,
              ),
              const SizedBox(width: AgoraSpacing.xs),
              const AgoraBadge(
                label: 'Zero Ambient AI',
                icon: Icons.lock_outline,
                variant: AgoraBadgeVariant.aegean,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
