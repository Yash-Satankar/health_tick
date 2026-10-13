import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Full-width light button with dark text (SPEC §9.1). Shows a spinner instead of the label while [loading].
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.buttonFill,
          foregroundColor: AppColors.buttonText,
          disabledBackgroundColor: loading ? AppColors.buttonFill : AppColors.buttonDisabled,
          disabledForegroundColor: AppColors.textSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radius)),
          textStyle: const TextStyle(fontSize: AppSizes.ctaFont, fontWeight: FontWeight.w700),
        ),
        child: loading
            ? const SizedBox(
                key: ValueKey('primary-button-spinner'),
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.buttonText),
              )
            : Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
