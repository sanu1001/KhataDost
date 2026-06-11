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

    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(color: titleColor, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing ??
          (onTap != null && enabled
              ? const Icon(Icons.chevron_right, color: AppColors.textHint)
              : null),
      onTap: enabled ? onTap : null,
    );
  }
}
