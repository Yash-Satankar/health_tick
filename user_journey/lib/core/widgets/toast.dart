import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Short message at the bottom of the screen (snackbar), optionally with a bold title.
void showToast(BuildContext context, String message, {String? title, Duration duration = const Duration(seconds: 3)}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        // Float above bottom action bars (e.g. the lesson CTA) so the toast never blocks them.
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        content: Text.rich(
          TextSpan(
            children: [
              if (title != null && title.isNotEmpty)
                TextSpan(
                  text: '$title ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              TextSpan(text: message),
            ],
          ),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
}
