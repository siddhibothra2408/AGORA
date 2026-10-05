import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_button.dart';
import '../../../shared/design_system/agora_card.dart';
import '../../../shared/design_system/agora_input.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(_emailController.text, _passwordController.text);
    if (!mounted) return;
    if (!success) {
      final error = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error?.toString() ?? 'Login failed'),
          backgroundColor: AgoraColors.error,
        ),
      );
    }
  }

  Future<void> _handleGoogleLogin() async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (!mounted) return;
    if (!success) {
      final error = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error?.toString() ?? 'Google sign-in failed'),
          backgroundColor: AgoraColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AgoraColors.surfaceDim,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AgoraSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Agora Brand Header
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AgoraColors.aegeanContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 32,
                        color: AgoraColors.aegean,
                      ),
                    ),
                  ),
                  const SizedBox(height: AgoraSpacing.md),
                  Text(
                    'Agora',
                    style: AgoraTypography.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AgoraSpacing.xs),
                  Text(
                    'Consent-first group collaboration.\nAI only reads what you hand it.',
                    style: AgoraTypography.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AgoraSpacing.xxl),

                  // Login Form Card
                  AgoraCard(
                    padding: const EdgeInsets.all(AgoraSpacing.xl),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Sign In',
                            style: AgoraTypography.headlineMedium,
                          ),
                          const SizedBox(height: AgoraSpacing.lg),
                          AgoraTextField(
                            label: 'Email',
                            controller: _emailController,
                            hint: 'you@college.edu',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!v.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AgoraSpacing.md),
                          AgoraTextField(
                            label: 'Password',
                            controller: _passwordController,
                            hint: '••••••••',
                            obscureText: _obscurePassword,
                            prefixIcon: Icons.lock_outline,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _handleEmailLogin(),
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                                color: AgoraColors.navyMuted,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AgoraSpacing.lg),
                          AgoraButton(
                            label: 'Sign In with Email',
                            onPressed: isLoading ? null : _handleEmailLogin,
                            isLoading: isLoading,
                            isFullWidth: true,
                          ),
                          const SizedBox(height: AgoraSpacing.md),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(
                                  color: AgoraColors.surfaceBorder,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AgoraSpacing.md,
                                ),
                                child: Text(
                                  'OR',
                                  style: AgoraTypography.labelSmall,
                                ),
                              ),
                              const Expanded(
                                child: Divider(
                                  color: AgoraColors.surfaceBorder,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AgoraSpacing.md),
                          AgoraButton(
                            label: 'Continue with Google',
                            icon: Icons.g_mobiledata,
                            variant: AgoraButtonVariant.secondary,
                            onPressed: isLoading ? null : _handleGoogleLogin,
                            isFullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AgoraSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: AgoraTypography.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Create one'),
                      ),
                    ],
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
