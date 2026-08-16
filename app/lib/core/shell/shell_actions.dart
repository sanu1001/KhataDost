import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../navigation/navigation_cubit.dart';
import '../theme/app_theme.dart';

/// Shared app-bar trailing action: the Settings entry point.
/// Rendered as a soft circular chip so every page header matches.
class ShellActions extends StatelessWidget {
  const ShellActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: AppColors.cardBg,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.read<NavigationCubit>().pushSettings(),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.settings_outlined,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
