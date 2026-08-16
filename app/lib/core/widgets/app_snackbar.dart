import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The ONLY way the app shows transient feedback.
///
/// Usage:
///   AppSnackbar.success(context, 'Bill saved');
///   AppSnackbar.error(context, state.errorMessage!);
///   AppSnackbar.info(context, 'Coming soon');
///
/// One voice everywhere: floating pill, leading icon chip, auto-clears any
/// snackbar already on screen so messages never queue up behind each other.
abstract class AppSnackbar {
  static void success(BuildContext context, String message) => _show(
    context,
    message: message,
    icon: Icons.check_circle_rounded,
    background: const Color(0xFF15803D),
    duration: const Duration(milliseconds: 2400),
  );

  static void error(BuildContext context, String message) => _show(
    context,
    message: message,
    icon: Icons.error_rounded,
    background: const Color(0xFFB91C1C),
    duration: const Duration(milliseconds: 3500),
  );

  static void info(BuildContext context, String message) => _show(
    context,
    message: message,
    icon: Icons.info_rounded,
    background: AppColors.textPrimary,
    duration: const Duration(milliseconds: 2400),
  );

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color background,
    required Duration duration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: background,
          elevation: 2,
          duration: duration,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
