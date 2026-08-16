import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Reusable settings row. A disabled tile (enabled: false) renders greyed and
/// ignores taps — used for the "Coming soon" preference stubs.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color titleColor = destructive
        ? AppColors.error
        : (enabled ? AppColors.textPrimary : AppColors.textHint);
    final Color iconColor = destructive
        ? AppColors.error
        : (enabled ? AppColors.primary : AppColors.textHint);
    final Color iconBg = destructive
        ? AppColors.errorSurface
        : (enabled ? AppColors.primarySurface : AppColors.surfaceVariant);

    return ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textHint,
              ),
            ),
      trailing: trailing ??
          (onTap != null && enabled
              ? const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint)
              : null),
      onTap: enabled ? onTap : null,
    );
  }
}
