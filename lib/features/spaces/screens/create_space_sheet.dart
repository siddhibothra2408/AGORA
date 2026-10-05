import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_radius.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_button.dart';
import '../../../shared/design_system/agora_input.dart';
import '../../profile/repositories/profile_repository.dart';
import '../repositories/space_repository.dart';

class CreateSpaceSheet extends ConsumerStatefulWidget {
  const CreateSpaceSheet({super.key});

  @override
  ConsumerState<CreateSpaceSheet> createState() => _CreateSpaceSheetState();
}

class _CreateSpaceSheetState extends ConsumerState<CreateSpaceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _charterController = TextEditingController(
    text: 'All members agree that AI has no ambient access and proposals require explicit human approval.',
  );
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _charterController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete your profile first.')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final space = await ref
          .read(spaceRepositoryProvider)
          .createSpace(
            name: _nameController.text,
            description: _descriptionController.text,
            charter: _charterController.text,
            creator: profile,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      context.go('/spaces/${space.id}/chat');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating space: $e'),
          backgroundColor: AgoraColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AgoraColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AgoraRadius.xl),
        ),
      ),
      padding: EdgeInsets.only(
        top: AgoraSpacing.lg,
        left: AgoraSpacing.xl,
        right: AgoraSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AgoraSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Text('Create New Space', style: AgoraTypography.headlineLarge),
              const SizedBox(height: AgoraSpacing.xs),
              Text(
                'Establish a collaboration space with transparent boundaries and consent rules.',
                style: AgoraTypography.bodyMedium,
              ),
              const SizedBox(height: AgoraSpacing.lg),
              AgoraTextField(
                label: 'Space Name',
                controller: _nameController,
                hint: 'e.g. Senior Capstone Team',
                prefixIcon: Icons.forum_outlined,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Space name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AgoraSpacing.md),
              AgoraTextField(
                label: 'Description',
                controller: _descriptionController,
                hint: 'What is this space focused on?',
                prefixIcon: Icons.description_outlined,
                maxLines: 2,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AgoraSpacing.md),
              AgoraTextField(
                label: 'Space Charter',
                controller: _charterController,
                hint: 'Constitutional rules of the space',
                prefixIcon: Icons.gavel_outlined,
                maxLines: 3,
                helperText: 'Governs AI boundaries and collaboration norms.',
              ),
              const SizedBox(height: AgoraSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isCreating
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AgoraSpacing.md),
                  AgoraButton(
                    label: 'Create Space',
                    isLoading: _isCreating,
                    onPressed: _isCreating ? null : _handleCreate,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
