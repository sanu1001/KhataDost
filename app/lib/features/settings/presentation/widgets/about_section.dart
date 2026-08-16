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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(height: 10),
          const Text(
            _appName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            _tagline,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            '$_version  ·  Built with Flutter & Go',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          const SizedBox(height: 8),
          const SelectableText(
            _repoUrl,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
