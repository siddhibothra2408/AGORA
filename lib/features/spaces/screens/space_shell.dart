import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_badge.dart';
import '../../../shared/design_system/agora_states.dart';
import '../repositories/space_repository.dart';

class SpaceShell extends ConsumerWidget {
  const SpaceShell({super.key, required this.spaceId, required this.child});

  final String spaceId;
  final Widget child;

  int _getCurrentIndex(String location) {
    if (location.endsWith('/board')) return 1;
    if (location.endsWith('/pulse')) return 2;
    return 0; // Default to Chat
  }

  void _onTabSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/spaces/$spaceId/chat');
        break;
      case 1:
        context.go('/spaces/$spaceId/board');
        break;
      case 2:
        context.go('/spaces/$spaceId/pulse');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaceAsync = ref.watch(currentSpaceProvider(spaceId));
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _getCurrentIndex(location);

    return spaceAsync.when(
      loading: () => const Scaffold(
        body: AgoraLoadingIndicator(message: 'Entering Space...'),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/spaces'),
          ),
        ),
        body: AgoraErrorView(
          title: 'Unable to load Space',
          message: err.toString(),
          onRetry: () => ref.invalidate(currentSpaceProvider(spaceId)),
        ),
      ),
      data: (space) {
        if (space == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/spaces'),
              ),
            ),
            body: const AgoraEmptyState(
              title: 'Space Not Found',
              message: 'This space may have been archived or you do not have permission to view it.',
            ),
          );
        }

        return Scaffold(
          backgroundColor: AgoraColors.surfaceDim,
          appBar: AppBar(
            backgroundColor: AgoraColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AgoraColors.navy),
              onPressed: () => context.go('/spaces'),
            ),
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        space.name,
                        style: AgoraTypography.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AgoraSpacing.xs),
                    const AgoraBadge(
                      label: 'CHARTER ACTIVE',
                      variant: AgoraBadgeVariant.neutral,
                    ),
                  ],
                ),
                Text(
                  '${space.memberCount} ${space.memberCount == 1 ? 'member' : 'members'} · Consent-First',
                  style: AgoraTypography.bodySmall,
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: const BoxDecoration(
                  color: AgoraColors.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: AgoraColors.surfaceBorder,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _SpaceTabButton(
                      label: 'Chat',
                      icon: Icons.chat_bubble_outline,
                      isSelected: selectedIndex == 0,
                      onTap: () => _onTabSelected(context, 0),
                    ),
                    _SpaceTabButton(
                      label: 'Board',
                      icon: Icons.dashboard_outlined,
                      isSelected: selectedIndex == 1,
                      onTap: () => _onTabSelected(context, 1),
                    ),
                    _SpaceTabButton(
                      label: 'Pulse',
                      icon: Icons.insights_outlined,
                      isSelected: selectedIndex == 2,
                      onTap: () => _onTabSelected(context, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: child,
        );
      },
    );
  }
}

class _SpaceTabButton extends StatelessWidget {
  const _SpaceTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isSelected ? AgoraColors.aegean : AgoraColors.navyMuted;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected ? AgoraColors.aegean : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: AgoraSpacing.xs),
                Text(
                  label,
                  style: AgoraTypography.labelMedium.copyWith(
                    color: fg,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
