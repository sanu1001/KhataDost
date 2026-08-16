import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The ONLY confirmation dialog in the app.
///
/// Usage:
///   final ok = await showConfirmDialog(
///     context,
///     title: 'Delete item?',
///     message: '"Tata Salt" will be removed from your inventory.',
///     confirmLabel: 'Delete',
///     destructive: true,
///   );
///   if (ok) { ... }
///
/// Returns false on dismiss/cancel — never null.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final accentColor = destructive ? AppColors.error : AppColors.primary;
  final accentBg = destructive ? AppColors.errorSurface : AppColors.primarySurface;
  final effectiveIcon =
      icon ?? (destructive ? Icons.delete_outline_rounded : Icons.help_outline_rounded);

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(effectiveIcon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            minimumSize: const Size(88, 44),
          ),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: accentColor,
            minimumSize: const Size(112, 44),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
