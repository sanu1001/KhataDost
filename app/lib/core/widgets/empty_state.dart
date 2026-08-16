import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The ONLY empty / error-state body in the app.
///
/// Usage (empty):
///   EmptyState(
///     icon: Icons.people_outline_rounded,
///     title: 'No customers yet',
///     subtitle: 'Add your first customer to start tracking udhaar.',
///     actionLabel: 'Add customer',
///     onAction: () => ...,
///   )
///
/// Usage (load failure):
///   EmptyState.error(message: state.errorMessage, onRetry: () => ...)
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add_rounded,
    this.iconColor = AppColors.primary,
    this.iconBackground = AppColors.primarySurface,
  });

  /// Convenience for "couldn't load" bodies — red accents + retry button.
  factory EmptyState.error({
    Key? key,
    String? message,
    VoidCallback? onRetry,
  }) =>
      EmptyState(
        key: key,
        icon: Icons.cloud_off_rounded,
        title: 'Something went wrong',
        subtitle: message ?? 'Please check your connection and try again.',
        actionLabel: onRetry == null ? null : 'Retry',
        onAction: onRetry,
        actionIcon: Icons.refresh_rounded,
        iconColor: AppColors.error,
        iconBackground: AppColors.errorSurface,
      );

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 24, 36, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: iconColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
                icon: Icon(actionIcon, size: 20),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
