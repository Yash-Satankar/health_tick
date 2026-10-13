import 'package:flutter/material.dart';

import '../copy/app_copy.dart';
import '../error/failure.dart';
import '../theme/tokens.dart';

/// Full-area error with a Retry button (SPEC §10). Texts come from app_copy (or FallbackMessages).
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, required this.copy, required this.onRetry, this.message});

  final Failure failure;
  final AppCopy copy;
  final VoidCallback? onRetry;

  /// Overrides the failure's message (e.g. an empty-state text).
  final String? message;

  @override
  Widget build(BuildContext context) {
    final title = failure.titleKey == null ? null : copy(failure.titleKey!);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failure is NetworkFailure ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 48,
              color: AppColors.textSecondary,
            ),
            if (title != null && title.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              message ?? copy(failure.messageKey),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                key: const ValueKey('error-retry'),
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.textSecondary),
                ),
                child: Text(copy('error.retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
