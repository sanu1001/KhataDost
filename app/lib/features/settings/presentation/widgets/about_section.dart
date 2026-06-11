import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Dep-free About block. The version lives here as a local const (NOT in
/// app_constants.dart, which is git skip-worktree'd, so a const added there
/// would never be committed). Bump [_version] on release.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  static const String _appName = 'KhataDost';
  static const String _tagline = 'Your shop ledger, made faster.';
  static const String _version = 'v1.0.0';
  static const String _repoUrl = 'https://github.com/sanu1001/KhataDost';

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        children: [
          Text(
            _appName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            _tagline,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          SizedBox(height: 8),
          Text(
            _version,
            style: TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
          SizedBox(height: 4),
          Text(
            'Built with Flutter & Go',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          SizedBox(height: 10),
          SelectableText(
            _repoUrl,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.primaryLight),
          ),
        ],
      ),
    );
  }
}
