import 'package:flutter/material.dart';

import '../../core/theme/agora_colors.dart';
import '../../core/theme/agora_radius.dart';
import '../../core/theme/agora_spacing.dart';
import '../../core/theme/agora_typography.dart';

/// Agora Text Field
class AgoraTextField extends StatelessWidget {
  const AgoraTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.helperText,
    this.errorText,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final String? helperText;
  final String? errorText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AgoraTypography.labelMedium.copyWith(
            color: AgoraColors.navy,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AgoraSpacing.xs),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          enabled: enabled,
          autofocus: autofocus,
          style: AgoraTypography.bodyLarge.copyWith(
            color: enabled ? AgoraColors.navyDark : AgoraColors.navyDisabled,
          ),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            helperText: helperText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20, color: AgoraColors.navyMuted)
                : null,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AgoraSpacing.md,
              vertical: AgoraSpacing.sm + 2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Agora Search Field
class AgoraSearchField extends StatelessWidget {
  const AgoraSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onClear,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AgoraSpacing.minTouchTarget,
      decoration: BoxDecoration(
        color: AgoraColors.surfaceContainer,
        borderRadius: AgoraRadius.borderMd,
        border: Border.all(color: AgoraColors.surfaceBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AgoraTypography.bodyMedium.copyWith(color: AgoraColors.navyDark),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AgoraColors.navyMuted,
          ),
          suffixIcon: controller?.text.isNotEmpty == true
              ? IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AgoraColors.navyMuted,
                  ),
                  onPressed: () {
                    controller?.clear();
                    onClear?.call();
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AgoraSpacing.sm,
            vertical: AgoraSpacing.xs,
          ),
        ),
      ),
    );
  }
}
