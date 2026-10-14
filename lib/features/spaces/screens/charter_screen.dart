import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_radius.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_button.dart';
import '../models/ai_consent_state.dart';
import '../repositories/space_repository.dart';

enum CharterConsentChoice { allowed, withheld }

/// Charter Screen & Re-Consent UX Gate
///
/// Implements the consent-first invariant:
/// - Two equal-weight cards: Allow vs Withhold
/// - NEITHER preselected
/// - Continue disabled until explicitly chosen
/// - Transparent copy explaining pseudonymization, unredacted message text,
///   public auditability, future-only mutability, and non-E2EE reality.
class CharterScreen extends ConsumerStatefulWidget {
  const CharterScreen({
    super.key,
    required this.spaceId,
    this.charterVersion = 1,
    this.onConsentSubmitted,
  });

  final String spaceId;
  final int charterVersion;
  final VoidCallback? onConsentSubmitted;

  @override
  ConsumerState<CharterScreen> createState() => _CharterScreenState();
}

class _CharterScreenState extends ConsumerState<CharterScreen> {
  CharterConsentChoice? _selectedChoice;
  bool _isSubmitting = false;

  Future<void> _handleContinue() async {
    if (_selectedChoice == null || _isSubmitting) return;

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() => _isSubmitting = true);
    try {
      final functions = ref.read(firebaseFunctionsProvider);
      if (functions != null) {
        await functions.httpsCallable('setMyConsent').call({
          'spaceId': widget.spaceId,
          'consent': _selectedChoice == CharterConsentChoice.allowed
              ? 'allowed'
              : 'withheld',
          'expectedCharterVersion': widget.charterVersion,
        });
      } else {
        // Fallback for tests/local mode
        await ref
            .read(spaceRepositoryProvider)
            .updateMemberConsent(
              spaceId: widget.spaceId,
              uid: uid,
              consentState: _selectedChoice == CharterConsentChoice.allowed
                  ? MemberConsentState.consented
                  : MemberConsentState.withheld,
            );
      }

      if (mounted) {
        if (widget.onConsentSubmitted != null) {
          widget.onConsentSubmitted!();
        } else {
          Navigator.of(context).maybePop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record consent: $e'),
            backgroundColor: AgoraColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgoraColors.surfaceDim,
      appBar: AppBar(
        title: const Text('Space Charter & Consent'),
        backgroundColor: AgoraColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AgoraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.all(AgoraSpacing.md),
                decoration: BoxDecoration(
                  color: AgoraColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AgoraRadius.md),
                  border: Border.all(color: AgoraColors.surfaceBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AgoraColors.navy,
                      size: 20,
                    ),
                    const SizedBox(width: AgoraSpacing.sm),
                    Expanded(
                      child: Text(
                        'Agora is not end-to-end encrypted: messages live in Firebase and are readable by Space members. AI never reads the chat on its own.',
                        style: AgoraTypography.bodySmall.copyWith(
                          color: AgoraColors.navyDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AgoraSpacing.lg),

              Text(
                'Choose your AI handoff consent',
                style: AgoraTypography.headlineMedium,
              ),
              const SizedBox(height: AgoraSpacing.xs),
              Text(
                'Charter Version ${widget.charterVersion} · You can change this choice anytime.',
                style: AgoraTypography.bodySmall,
              ),
              const SizedBox(height: AgoraSpacing.lg),

              // Two equal-weight cards: neither preselected
              Expanded(
                child: ListView(
                  children: [
                    // Card 1: Allow
                    _ConsentChoiceCard(
                      title: 'Allow my messages in AI handoffs',
                      subtitle:
                          'Other members may choose to hand specific messages of mine to AI for a stated purpose. AI never reads the chat on its own.\n\n'
                          '• Sender names are replaced by labels like "Member A"\n'
                          '• Emails, phone numbers, and long numbers are redacted\n'
                          '• Names and words written inside messages are sent as written\n'
                          '• Everyone in the space can see every handoff in the AI Ledger',
                      icon: Icons.check_circle_outline,
                      isSelected:
                          _selectedChoice == CharterConsentChoice.allowed,
                      accentColor: AgoraColors.aegean,
                      onTap: () {
                        setState(() {
                          _selectedChoice = CharterConsentChoice.allowed;
                        });
                      },
                    ),
                    const SizedBox(height: AgoraSpacing.md),

                    // Card 2: Withhold
                    _ConsentChoiceCard(
                      title: 'Withhold my messages from AI',
                      subtitle:
                          'My messages are never sent to AI by anyone else.\n\n'
                          '• Others in the Space can see my choice\n'
                          '• You may change your choice anytime for future handoffs\n'
                          '• Data already processed in past handoffs cannot be recalled\n'
                          '• You can still hand off your own messages at any time',
                      icon: Icons.block_outlined,
                      isSelected:
                          _selectedChoice == CharterConsentChoice.withheld,
                      accentColor: AgoraColors.withhold,
                      onTap: () {
                        setState(() {
                          _selectedChoice = CharterConsentChoice.withheld;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AgoraSpacing.md),

              // Continue button disabled until chosen
              AgoraButton(
                label: 'Continue to Space',
                isLoading: _isSubmitting,
                onPressed: _selectedChoice == null || _isSubmitting
                    ? null
                    : _handleContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentChoiceCard extends StatelessWidget {
  const _ConsentChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AgoraRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AgoraSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? AgoraColors.surface
              : AgoraColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AgoraRadius.lg),
          border: Border.all(
            color: isSelected ? accentColor : AgoraColors.surfaceBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 24),
                const SizedBox(width: AgoraSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: AgoraTypography.titleMedium.copyWith(
                      color: AgoraColors.navyDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? accentColor
                          : AgoraColors.navyDisabled,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentColor,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AgoraSpacing.sm),
            Text(
              subtitle,
              style: AgoraTypography.bodySmall.copyWith(
                color: AgoraColors.navySubtle,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
