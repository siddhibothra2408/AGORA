import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_badge.dart';
import '../../../shared/design_system/agora_button.dart';
import '../../../shared/design_system/agora_card.dart';
import '../../../shared/design_system/agora_states.dart';
import '../../auth/controllers/auth_controller.dart';
import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final user = ref.watch(firebaseAuthProvider)?.currentUser;

    return Scaffold(
      backgroundColor: AgoraColors.surfaceDim,
      appBar: AppBar(title: Text('Me', style: AgoraTypography.headlineLarge)),
      body: profileAsync.when(
        loading: () =>
            const AgoraLoadingIndicator(message: 'Loading profile...'),
        error: (err, _) => AgoraErrorView(
          title: 'Could not load profile',
          message: err.toString(),
          onRetry: () => ref.invalidate(currentProfileProvider),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: AgoraButton(
                label: 'Set up Profile',
                onPressed: () => context.go('/onboarding'),
              ),
            );
          }

          final isWithheldDefault =
              profile.defaultAiConsent == DefaultAiConsent.withheld;

          return ListView(
            padding: const EdgeInsets.all(AgoraSpacing.lg),
            children: [
              // Identity Header Card
              AgoraCard(
                padding: const EdgeInsets.all(AgoraSpacing.xl),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AgoraColors.aegeanContainer,
                      child: Text(
                        profile.displayName.isNotEmpty
                            ? profile.displayName[0].toUpperCase()
                            : '?',
                        style: AgoraTypography.displayMedium.copyWith(
                          color: AgoraColors.aegeanDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: AgoraSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            style: AgoraTypography.headlineMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${profile.handle}',
                            style: AgoraTypography.titleMedium.copyWith(
                              color: AgoraColors.aegean,
                            ),
                          ),
                          if (user?.email != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              user!.email!,
                              style: AgoraTypography.bodySmall,
                            ),
                          ],
                          if (profile.bio != null &&
                              profile.bio!.isNotEmpty) ...[
                            const SizedBox(height: AgoraSpacing.sm),
                            Text(
                              profile.bio!,
                              style: AgoraTypography.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AgoraSpacing.lg),

              // AI Consent Posture Section
              Text('Consent Posture', style: AgoraTypography.headlineMedium),
              const SizedBox(height: AgoraSpacing.xs),
              AgoraCard(
                padding: const EdgeInsets.all(AgoraSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Default AI Consent',
                          style: AgoraTypography.titleMedium,
                        ),
                        AgoraConsentBadge(isWithheld: isWithheldDefault),
                      ],
                    ),
                    const SizedBox(height: AgoraSpacing.xs),
                    Text(
                      isWithheldDefault
                          ? 'Your messages are withheld from AI handoffs by default unless you toggle otherwise.'
                          : 'Your messages can be included in manual human handoffs to AI by default.',
                      style: AgoraTypography.bodySmall,
                    ),
                    const SizedBox(height: AgoraSpacing.md),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Withhold All Messages by Default'),
                      subtitle: const Text(
                        'Enforce strictest default privacy shield across all spaces.',
                      ),
                      value: isWithheldDefault,
                      activeTrackColor: AgoraColors.withhold,
                      onChanged: (bool value) async {
                        final updated = profile.copyWith(
                          defaultAiConsent: value
                              ? DefaultAiConsent.withheld
                              : DefaultAiConsent.optIn,
                        );
                        await ref
                            .read(profileRepositoryProvider)
                            .updateProfile(updated);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AgoraSpacing.lg),

              // Transparency & Architecture Disclosure
              Text(
                'Security & Transparency Notice',
                style: AgoraTypography.headlineMedium,
              ),
              const SizedBox(height: AgoraSpacing.xs),
              AgoraCard(
                padding: const EdgeInsets.all(AgoraSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 20,
                          color: AgoraColors.navy,
                        ),
                        const SizedBox(width: AgoraSpacing.xs),
                        Text(
                          'Consent-First Architecture',
                          style: AgoraTypography.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AgoraSpacing.xs),
                    Text(
                      'Agora is consent-first and transparent, NOT end-to-end encrypted. '
                      'All space members can see which messages were handed to AI and who authorized it. '
                      'AI has zero background or ambient monitoring.',
                      style: AgoraTypography.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AgoraSpacing.xl),

              // Sign Out
              AgoraButton(
                label: 'Sign Out',
                icon: Icons.logout,
                variant: AgoraButtonVariant.outlined,
                isFullWidth: true,
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
