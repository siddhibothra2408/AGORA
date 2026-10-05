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
import '../../../shared/design_system/agora_input.dart';
import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _handleController = TextEditingController();
  final _bioController = TextEditingController();

  DefaultAiConsent _defaultConsent = DefaultAiConsent.optIn;
  bool _isCheckingHandle = false;
  String? _handleStatusMessage;
  bool _isHandleAvailable = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final authUser = ref.read(firebaseAuthProvider)?.currentUser;
    if (authUser?.displayName != null) {
      _displayNameController.text = authUser!.displayName!;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _handleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _checkHandle(String handle) async {
    final trimmed = handle.toLowerCase().trim();
    if (trimmed.length < 3) {
      setState(() {
        _isHandleAvailable = false;
        _handleStatusMessage = 'Handle must be at least 3 characters.';
      });
      return;
    }

    setState(() {
      _isCheckingHandle = true;
      _handleStatusMessage = null;
    });

    try {
      final available = await ref
          .read(profileRepositoryProvider)
          .isHandleAvailable(trimmed);
      if (!mounted) return;
      setState(() {
        _isCheckingHandle = false;
        _isHandleAvailable = available;
        _handleStatusMessage = available
            ? '@$trimmed is available!'
            : '@$trimmed is already taken.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingHandle = false;
        _isHandleAvailable = true; // In offline preview mode
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User session not found. Please log in again.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(profileRepositoryProvider)
          .createProfile(
            uid: uid,
            handle: _handleController.text,
            displayName: _displayNameController.text,
            bio: _bioController.text.isNotEmpty ? _bioController.text : null,
            defaultAiConsent: _defaultConsent,
          );
      if (!mounted) return;
      context.go('/spaces');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AgoraColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgoraColors.surfaceDim,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AgoraSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Setup Your Identity',
                    style: AgoraTypography.displayMedium,
                  ),
                  const SizedBox(height: AgoraSpacing.xs),
                  Text(
                    'Choose how you appear across spaces and configure your initial consent posture.',
                    style: AgoraTypography.bodyMedium,
                  ),
                  const SizedBox(height: AgoraSpacing.xl),

                  AgoraCard(
                    padding: const EdgeInsets.all(AgoraSpacing.xl),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AgoraTextField(
                            label: 'Display Name',
                            controller: _displayNameController,
                            hint: 'Alex Morgan',
                            prefixIcon: Icons.badge_outlined,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Display name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AgoraSpacing.md),

                          AgoraTextField(
                            label: 'Unique Handle',
                            controller: _handleController,
                            hint: 'alex',
                            prefixIcon: Icons.alternate_email,
                            textInputAction: TextInputAction.next,
                            onChanged: (val) {
                              _checkHandle(val);
                            },
                            helperText: _handleStatusMessage,
                            suffix: _handleStatusMessage != null
                                ? Icon(
                                    _isHandleAvailable
                                        ? Icons.check_circle_outline
                                        : Icons.cancel_outlined,
                                    color: _isHandleAvailable
                                        ? AgoraColors.success
                                        : AgoraColors.error,
                                    size: 20,
                                  )
                                : null,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Handle is required';
                              }
                              if (v.trim().length < 3 || v.trim().length > 20) {
                                return 'Must be between 3 and 20 characters';
                              }
                              final regex = RegExp(r'^[a-zA-Z0-9_]+$');
                              if (!regex.hasMatch(v.trim())) {
                                return 'Only letters, numbers, and underscores';
                              }
                              return null;
                            },
                          ),
                          if (_isCheckingHandle)
                            const Padding(
                              padding: EdgeInsets.only(top: AgoraSpacing.xs),
                              child: LinearProgressIndicator(
                                backgroundColor: AgoraColors.surfaceContainer,
                                valueColor: AlwaysStoppedAnimation(
                                  AgoraColors.aegean,
                                ),
                              ),
                            ),
                          const SizedBox(height: AgoraSpacing.md),

                          AgoraTextField(
                            label: 'Bio (Optional)',
                            controller: _bioController,
                            hint: 'Computer Science major, Class of 2026',
                            prefixIcon: Icons.notes_outlined,
                            maxLines: 2,
                            textInputAction: TextInputAction.done,
                          ),
                          const SizedBox(height: AgoraSpacing.lg),

                          const Divider(),
                          const SizedBox(height: AgoraSpacing.md),

                          // Default Consent Preference
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Default AI Consent',
                                style: AgoraTypography.titleMedium,
                              ),
                              AgoraConsentBadge(
                                isWithheld:
                                    _defaultConsent ==
                                    DefaultAiConsent.withheld,
                              ),
                            ],
                          ),
                          const SizedBox(height: AgoraSpacing.xs),
                          Text(
                            'You can withhold specific messages at any time. When set to Withheld, your messages are by default excluded from AI handoffs.',
                            style: AgoraTypography.bodySmall,
                          ),
                          const SizedBox(height: AgoraSpacing.sm),

                          SegmentedButton<DefaultAiConsent>(
                            segments: const [
                              ButtonSegment(
                                value: DefaultAiConsent.optIn,
                                label: Text('Eligible by Default'),
                                icon: Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                ),
                              ),
                              ButtonSegment(
                                value: DefaultAiConsent.withheld,
                                label: Text('Withheld by Default'),
                                icon: Icon(Icons.shield_outlined, size: 16),
                              ),
                            ],
                            selected: {_defaultConsent},
                            onSelectionChanged: (set) {
                              setState(() {
                                _defaultConsent = set.first;
                              });
                            },
                          ),

                          const SizedBox(height: AgoraSpacing.xl),
                          AgoraButton(
                            label: 'Complete Profile',
                            onPressed: _isSubmitting ? null : _handleSubmit,
                            isLoading: _isSubmitting,
                            isFullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
